package NAP::policy;
# ABSTRACT: enable all of the features of Modern Perl at NAP with one command

=head1 NAME

NAP::policy

=head1 SYNOPSIS

  package Whatever;
  use NAP::policy;

  # you get many goodies

=head1 DESCRIPTION

This module will do the same as:

  use strict;
  use warnings FATAL => 'all';
  no warnings 'experimental::smartmatch';
  use utf8;
  use true;
  use Try::Tiny;
  use Smart::Match instance_of => { -as => 'match_instance_of' };
  use Carp;
  use namespace::autoclean;
  use feature ':5.18';
  no multidimensional;
  no bareword::filehandles;

The C<use feature> enables C<say>, C<state>, C<switch> and
C<unicode_strings>.

Note that C<unicode_strings> only means that code points between 128
and 255 have Unicode character semantics reagardless of the internal
representation. The handling of binary strings (consisting entirely of
codepoints in the 0-255 range) is not affected. See L<perlunicode/The
"Unicode Bug"> for details.

In addition, some parameters give additional behaviour:

=over 4

=item C<'class'>

will import L<Moose>, and make your class immutable

=item C<'role'>

will import L<Moose::Role>

=item C<'exception'>

will make your class derived from L<NAP::Exception>

=item C<'exporter'>

will prevent C<import> from being auto-cleaned

=item C<'simple_exception'>

imports L</simple_exception> in your package, will die if the
package's name does not end in C<::Exception>

=item C<'match'>

will import all of L<Smart::Match>, but each function will be prefixed
by C<match_> (so you get C<match_all> instead of C<all>); see L</Smart
Match policy> for details on how to use these

=item C<'overloads'>

no-op; used to prevent prevent operator overloads from being
auto-cleaned, but that is done automatically now.

=item C<'dont_clean'>

this options takes a value:

  dont_clean => [ 'subname', 'another_name' ],

it will prevent the specified sub names from being auto-cleaned (yes,
C<'exporter'> is equivalent to C<< dont_clean => ['import'] >>)

=item C<'test'>

will add:

  use lib 't/lib';
  use Test::Most;
  use Data::Printer;

in addition, all output streams are filtered via L<PerlIO::via::SafeEscape>

=item C<'tt'>

historical, used to select L<Try::Tiny> instead of L<TryCatch>, but we
no longer support L<TryCatch>, so this option does nothing

=back

=cut

use 5.018;
use strict;
use warnings FATAL => 'all';
no warnings 'experimental::smartmatch';
use utf8 ();
use feature ();
use true ();
use Carp ();
use Try::Tiny ();
use namespace::autoclean 0.17;
use Hook::AfterRuntime;
use File::ShareDir ();
use Data::OptList;
use multidimensional ();
use bareword::filehandles ();
use Import::Into;
use Module::Runtime qw(use_module);
use Smart::Match ();

sub import {
    my ($class,@opts) = @_;
    my $caller = caller;

    strict->import();
    feature->import( ':5.18' );
    utf8->import($caller);
    true->import();
    Carp->import::into($caller);
    multidimensional->unimport();
    bareword::filehandles->unimport();
    Try::Tiny->import::into($caller);
    Smart::Match->import({into=>$caller},'instance_of' => { -as=>'match_instance_of' });

    @opts = @{
        Data::OptList::mkopt(
            \@opts,
            {
                moniker => 'NAP::policy import options',
            }
        )
      };

    my @no_clean;
    for my $opt_spec (@opts) {
        my ($opt,$opt_args) = @$opt_spec;
        given ($opt) {
            when ('tt') {
            }
            when ('match') {
                require Smart::Match;
                Smart::Match->import({into=>$caller},-all => { -prefix=>'match_' });
            }
            when ('class') {
                require Moose;
                Moose->import({into=>$caller});
                after_runtime {
                    $caller->meta->make_immutable;
                }
            };
            when ('role') {
                require Moose::Role;
                Moose::Role->import({into=>$caller});
            };
            when ('simple_exception') {
                require Sub::Install;
                Carp::croak 'simple_exception should only be imported into a package called *::Exception'
                      unless $caller =~ m{::Exception$};
                Sub::Install::install_sub({
                    code => \&simple_exception,
                    into => $caller,
                    as => 'simple_exception',
                });
            }
            when ('exception') {
                require Moose;
                Moose->import({into=>$caller});
                Class::MOP::get_metaclass_by_name($caller)->superclasses('NAP::Exception');
                # if the exception uses NAP::Exception::Role::StackTrace,
                # the inlined constructor won't work properly (there's an
                # C<around new>!, so we avoid inlining it
                after_runtime {
                    $caller->meta->make_immutable(inline_constructor=>0);
                }
            };
            when ('exporter') {
                push @no_clean, 'import';
            };
            when ('overloads') {
                # nothing to do, namespace::autoclean since 0.16
                # leaves overloads in place
            };
            when ('dont_clean') {
                if (!$opt_args) {
                    Carp::carp "ignoring dont_clean option without arrayref of subroutine names to keep";
                    next;
                }
                push @no_clean, @$opt_args;
            };
            when ('test') {
                foreach (
                    [qw(lib t/lib)],
                    [qw(Test::Most)],
                    [qw(Data::Printer)],
                ) {
                    my ($module, @args) = @{$_};
                    use_module($module)->import::into($caller, @args);
                }
                my $builder = Test::Builder->new;
                require PerlIO::via::SafeEscape;
                for my $stream_name (qw(output failure_output todo_output)) {
                    my $stream = $builder->$stream_name;
                    # the :raw makes sure we don't apply SafeEscape twice
                    binmode $stream, ':raw:via(SafeEscape)';
                    _autoflush($stream);
                }
            };
            default {
                Carp::carp "ignoring unknown import option '$_'";
            };
        }
    }

    # This must come after anything else that might change warning
    # levels in the caller (e.g. Moose)
    warnings->import('FATAL'=>'all');
    warnings->unimport('experimental::smartmatch');

    namespace::autoclean->import(
        -cleanee => $caller,
        -except => \@no_clean,
    );
}

sub _autoflush {
    my($fh) = shift;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;

    return;
}

=head1 Additional methods

=head2 C<mark_as_method>

  BEGIN { NAP::policy->mark_as_method($subname,$package); }

B<Deprecated>, use the C<dont_clean> option instead.

Heavily inspired from L<MooseX::MarkAsMethods>. Mark a (probably
imported) subroutine as a method, protecting it from
L<namespace::autoclean>.

B<NOTE>: this has to be called in a C<BEGIN> block, otherwise it won't
work. L<namespace::autoclean> gets run at the end of compilation, so
by the time a normal call to this functions gets executed, the
subroutine will have been cleaned already. A simpler way to get the
same result is to import C<NAP::policy> with the C<dont_clean>
option:

  use NAP::policy dont_clean => [$subname];

=cut

sub mark_as_method {
    my ($self,$method_name,$class)=@_;

    $class //= caller;

    require Class::MOP;
    my $meta=Class::MOP::Class->initialize($class);
    return if $meta->has_method($method_name);
    my $code = $meta->get_package_symbol({
        name  => $method_name,
        sigil => '&',
        type  => 'CODE',
    });

    do { warn "$method_name not found as a CODE symbol!"; return }
        unless defined $code;

    $meta->add_method(
        $method_name => (
            $meta->wrap_method_body(
                associated_metaclass => $meta,
                name => $method_name,
                body => $code,
            ),
        )
    );

    return;
}

=head2 C<mark_overloads_as_methods>

  NAP::policy->mark_overloads_as_methods($package);

B<Deprecated>, L<namespace::autoclean> now leaves overloads in place.

=cut

sub mark_overloads_as_methods { }

=head2 C<critic_profile>

  my $critic = Perl::Critic->new(
    -severity => 'stern',
    -profile  => NAP::policy->critic_profile,
  );

Returns the file name of the F<perlcritic.conf> that is part of the
policy distribution. You should use this method to get a
L<Perl::Critic> configuration that works on modules that use
L<NAP::policy>.

=cut

sub critic_profile {
    my ($self) = @_;

    return File::ShareDir::dist_file('NAP-policy','perlcritic.conf');
}

=head2 C<simple_exception>

   package MyApp::Exception;
   use NAP::policy 'simple_exception';
   simple_exception('BadExample','something bad happened at %{stack_trace}s');
   simple_exception('BadValue','the value %{value}s is bad',{
       attrs => ['value'],
   });
   simple_exception('Invalid','the value %{value}s is not valid, should match %{constraint}s ',{
       extends => 'BadValue',
       attrs => ['constraint'],
   });
   simple_exception('ShortLived','whatever',{
       stack_trace => 0,
   });

This functions simplifies creating exception classes in the most
common cases.

You can only call this function from a package with a name ending in
C<::Exception>. The reason is that C<simple_exception> will create
additional classes "under" the calling package's namespace, and we
want our exception classes to have sensible names.

The simples use is to just create a subclass of L<NAP::Exception> with
a default message, like the C<BadExample> above. That is equivalent
to:

  package MyApp::Exception::BadExample {
   use NAP::policy 'exception';
   has '+message' => ( default => 'something bad happened at %{stack_trace}s' );
  }

In most cases you should really set additional attributes to describe
what caused the exception. You can do that with the C<attrs> option,
passing an arrayref of attribute names. The C<BadValue> example above
is equivalent to:

  package MyApp::Exception::BadValue {
   use NAP::policy 'exception';
   has '+message' => ( default => 'the value %{value}s is bad' );
   has value => ( is => 'ro', required => 1 );
  }

You should structure your exceptions in a hierarchy, using the
C<extends> options. The C<Invalid> example is equivalent to:

  package MyApp::Exception::Invalid {
   use NAP::policy 'exception';
   extends 'MyApp::Exception::BadValue';
   has '+message' => ( default => 'the value %{value}s is not valid, should match %{constraint}s' );
   has constraint => ( is => 'ro', required => 1 );
  }

Finally, in some cases you don't need to capture the entire stack
trace when you throw an exception (for example, if you know that
you'll be catching it just a few frames out). You can use the
C<stack_trace> option to avoid it. The C<ShortLived> example is
equivalent to:

  package MyApp::Exception::ShortLived {
   use NAP::policy 'exception';
   with 'NAP::Exception::Role::NoStackTrace';
   has '+message' => ( default => 'whatever' );
  }

=cut

sub simple_exception {
    my ($exception_class_local_name,$message_default,$options) = @_;
    my $caller_package_name = caller;
    Carp::croak 'simple_exception should only be called from a package called *::Exception'
          unless $caller_package_name =~ m{::Exception$};
    Carp::croak 'exception name is required'
          unless $exception_class_local_name;
    Carp::croak 'a default message is required'
          unless $message_default;

    my $exception_class_name = "${caller_package_name}::${exception_class_local_name}";

    my @roles = ($options->{stack_trace}//1) ?
        () : ( roles => ['NAP::Exception::Role::NoStackTrace'] );

    require Class::Load;require NAP::Exception;
    my $superclass = $options->{extends} // 'NAP::Exception';
    unless (Class::Load::is_class_loaded($superclass)) {
        $superclass = "${caller_package_name}::${superclass}";
    }

    my @attrs = map {
        Moose::Meta::Attribute->new(
            $_ => (
                is => 'ro',
                required => 1,
            ),
        );
    } @{$options->{attrs} // []};

    my $exception_meta_class = Moose::Meta::Class->create(
        $exception_class_name,
        superclasses =>  [$superclass],
        @roles,
        attributes => \@attrs,
    );
    $exception_meta_class->add_attribute(
        '+message' => ( default => $message_default ),
    );

    return;
}

=head1 Migrating to C<Try::Tiny>

Using L<TryCatch> you'd write:

  try { ... }
  catch (SomeClass $e) { use($e) }
  catch (SomethingElse $e) { use($e) }
  catch ($e) { use($e) }

Using L<Try::Tiny> you'd write:

  try { ... }
  catch {
   # here you get the exception in $_
   when (match_instance_of('SomeClass')) { use($_) }
   when (match_instance_of('SomethingElse')) { use($_) }
   default { use($_) }
  }; # note the semi-colon

On the other hand, if your L<TryCatch> use did I<not> have a
unqualified C<catch ($e)>, you need to write C<default { die $_ }> to
re-throw the unhandled exception (yes, you really have to write C<die
$_>, read the documentation of L<die> to learn the ugly details;
C<die> without arguments won't do anything useful there).

Also, keep in mind that the blocks used by L<Try::Tiny> are actually
anonymous subroutines, so they get their own C<@_> (nothing in the
case of the C<try> block, the exception in the case of the C<catch>
block), and C<return> will return from the block, not the contanining
subroutine.

=head1 Smart Match policy

Smart match can simplify some expressions, but its full power is hard
to grasp and leads to hard-to-debug problems. Our policy is (subject
to review in the future):

=over 4

=item *

only use C<~~> with a scalar on the right-hand side, and on the
right-hand side one of the C<match_*`>> functions exported by C<use
NAP::policy 'match'> (see L<Smart::Match> for their documentation).

=item *

in the expression for C<when>, only use the C<match_*> functions

=back

This should remove all the ambiguity and guesswork from the
not-smart-enough match.

When you're working on a piece of code and you see a smart-match or a
C<given> / C<when>:

=over 4

=item *

if the code already imports C<NAP::policy>, align it to the policy
above

=item *

otherwise, consider porting it to C<NAP::policy> (but beware of the
now-fatal warnings! especially about using undef values)

=item *

otherwise, if it's easy, remove the smart-matches and C<given> /
C<when>

=item *

otherwise, add C<use experimental 'smatchmatch'> to the smallest
lexical scope of each instance of C<~~> or C<given> / C<when>

=back

=head1 CAVEATS

This module relies on:

=over 4

=item L<Hook::AfterRuntime>

(for the C<class> case) which only works if the module is loaded at
C<BEGIN> time (e.g. via C<use>) at package scope; why you would C<use
NAP::policy 'class'> in any other place than the top of the package is
beyond me.

=back

If you get weird behaviours when using this module, it's a good idea
to study the documentation of the above likely culprits.

=cut

1;
