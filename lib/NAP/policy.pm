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
  use utf8;
  use true;
  use TryCatch; # or use Try::Tiny, see below
  use Carp;
  use namespace::autoclean;
  use feature ':5.14';
  no multidimensional;
  no bareword::filehandles;

The C<use feature> enables C<say>, C<state>, C<switch> and
C<unicode_strings>. In the unlikely case you need to deal with binary
strings, remember to C<use bytes> in the smallest sensible lexical
scope.

In addition, some parameters give additional behaviour:

=over 4

=item C<'tt'>

will use L<Try::Tiny> instead of L<TryCatch>; L<TryCatch> will be
deprecated and removed in the near future, please start migrating to
L<Try::Tiny>

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

=item C<'overloads'>

will prevent operator overloads from being auto-cleaned

=item C<'dont_clean'>

this options takes a value:

  dont_clean => [ 'subname', 'another_name' ],

it will prevent the specified sub names from being auto-cleaned (yes,
C<'exporter'> is equivalent to C<< dont_clean => ['import'] >>)

=item C<'test'>

will add:

  use lib 't/lib';
  use Test::Most '!blessed';
  use Data::Printer;

=back

=cut

use 5.014;
use strict;
use warnings;
use utf8 ();
use feature ();
use true ();
use Carp ();
use Sub::Import ();
use namespace::autoclean;
use B::Hooks::EndOfScope;
use Hook::AfterRuntime;
use File::ShareDir ();
use Data::OptList;
use multidimensional ();
use bareword::filehandles ();

sub import {
    my ($class,@opts) = @_;
    my $caller = caller;

    strict->import();
    warnings->import('FATAL'=>'all');
    feature->import( ':5.14' );
    utf8->import($caller);
    true->import();
    Sub::Import->import('Carp',{into=>$caller});
    multidimensional->unimport();
    bareword::filehandles->unimport();

    my $catcher_package = 'TryCatch';

    @opts = @{
        Data::OptList::mkopt(
            \@opts,
            {
                moniker => 'NAP::policy import options',
            }
        )
      };

    for my $opt_spec (@opts) {
        my ($opt,$opt_args) = @$opt_spec;
        given ($opt) {
            when ('tt') {
                $catcher_package = 'Try::Tiny';
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
                on_scope_end {
                    __PACKAGE__->mark_as_method('import',$caller);
                }
            };
            when ('overloads') {
                on_scope_end {
                    __PACKAGE__->mark_overloads_as_methods($caller);
                }
            };
            when ('dont_clean') {
                if (!$opt_args) {
                    Carp::carp "ignoring dont_clean option without arrayref of subroutine names to keep";
                    next;
                }
                on_scope_end {
                    for my $method (@$opt_args) {
                        __PACKAGE__->mark_as_method($method,$caller)
                    }
                }
            };
            when ('test') {
                ## no critic ProhibitStringyEval
                require lib;
                lib->import('t/lib');
                # yes, this is ugly, but I couldn't find a better way;
                eval <<"MAGIC" or die "Couldn't set up testing policy: $@";
package $caller;
use Test::Most '-Test::Deep';
use Test::Deep '!blessed';
use Data::Printer;
1;
MAGIC
            };
            default {
                Carp::carp "ignoring unknown import option '$_'";
            };
        }
    }

    if ($catcher_package eq 'TryCatch') {
        require TryCatch;
        TryCatch->import({into=>$caller});
    }
    else {
        require Try::Tiny;
        Try::Tiny->export_to_level(1,$caller,'try','catch','finally');
    }

    # this must come after the on_scope_end call above, otherwise the
    # clean happens before the mark_as_method, and 'import' is cleaned
    # even though we don't want it to be
    namespace::autoclean->import(
        -cleanee => $caller,
    );
}

=head1 Additional methods

=head2 C<mark_as_method>

  BEGIN { NAP::policy->mark_as_method($subname,$package); }

Heavily inspired from L<MooseX::MarkAsMethods>. Mark a (probably
imported) subroutine as a method, protecting it from
L<namespace::autoclean>.

B<NOTE>: this has to be called in a C<BEGIN> block, otherwise it won't
work. L<namespace::autoclean> gets run at the end of compilation, so
by the time a normal call to this functions gets executed, the
subrouting will have been cleaned already. A simpler way to get the
same result is to import C<NAP::policy> with the C<dont_clean>
option:

  use NAP::policy dont_clean => [$subname];

=cut

sub mark_as_method {
    my ($self,$method_name,$class)=@_;

    $class //= caller;

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

Heavily inspired from L<MooseX::MarkAsMethods>. Mark an operator
overload as a method, protecting it from L<namespace::autoclean>.

=cut

sub mark_overloads_as_methods {
    my ($self,$class) = @_;

    $class //= caller;

    my $meta=Class::MOP::Class->initialize($class);
    my @overloads = grep { /^\(/ }
        keys %{$meta->get_all_package_symbols('CODE')};
    $self->mark_as_method($_,$class) for @overloads;

    return;
}

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
   with 'NAP::Exception::Role::StackTrace';
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

=head1 CAVEATS

This module relies on:

=over 4

=item L<B::Hooks::EndOfScope>

(to prevent auto-cleaning) which does clever things with C<%^H> and
C<DESTROY> hooks.

=item L<Hook::AfterRuntime>

(for the C<class> case) which only works if the module is loaded at
C<BEGIN> time (e.g. via C<use>) at package scope; why you would C<use
NAP::policy 'class'> in any other place than the top of the package is
beyond me.

=item L<Devel::Declare>

(via L<TryCatch>) which is deep scary voodoo, and will spit out
horrible error messages if you get things wrong.

=back

If you get weird behaviours when using this module, it's a good idea
to study the documentation of the above likely culprits.

=cut

1;
