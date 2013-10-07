package NAP::Exception;
use NAP::policy 'class','overloads','tt';
use NAP::Exception::Formatter;

# ABSTRACT: Exception base class

=head1 SYNOPSIS

  package My::Exc::NotFound {
   use NAP::policy 'exception';

   has what => ( is => 'ro', required => 1 );
   has '+message' => (
    default => 'I looked for %{what}s, but I could not find it at %{stack_trace}s',
   );
  }
  package My::Exc::NotFound::Product {
   use NAP::policy 'exception';
   extends 'My::Exc::NotFound';

   has '+message' => (
    default => 'The product %{what}s does not exist (%{stack_trace}s)',
   );
  }

Later:

  My::Exc::NotFound::Product->throw({what=>$the_pid});

and:

  try { get_the_product($user_input) }
  catch (My::Exc::NotFound::Product $e) {
    $self->log->warn("$e");
    $self->add_to_errors(translate('product_not_found',$e->what));
  }
  catch ($e) {
   $self->log->error("$e");
   $self->add_to_errors(translate('unexpected_error',$e));
  }

=head1 DESCRIPTION

This base class implements some minimal structure for exceptions,
allowing you to define the specifics.

The idea is that your exception classes form a sensible hierarchy, and
that each exception class has the attributes needed to identify what
went wrong and why.

The L</message> field is intended for internal diagnostic use (to
print to log files, for example), I<not> for direct user consumption
(although, if you really want to, you can use it for that as well). To
display error messages to the user, you should pass the relevant
values from the exception object just caught to the view's message
formatter, which may well go through some localisation mechanism.

This class is built on L<Throwable> and L<StackTrace::Auto>.

=cut

with 'Throwable','StackTrace::Auto';

use overload
  q{""}    => 'as_string',
  fallback => 1;


=method C<throw>

A constructor. Creates an object (passing all its arguments to
C<new>), then C<die>s with it.

=attr C<previous_exception>

Stores the value of C<$@> at the time the object was built. Helps when
re-throwing exceptions.

=attr C<stack_trace>

A stack trace captured at object creation via L<Devel::StackTrace>. To
avoid memory leaks and to make the trace somewhat legible, we override
the default parameters for the L<Devel::StackTrace> constructor,
setting:

 no_refs => 1,
 respect_overload => 1,
 message => '',
 indent => 1,

You can change this by modifying the C<_build_stack_trace_args> method.

=cut

around _build_stack_trace_args => sub {
    my ($orig,$self) = @_;

    my $ret = $self->$orig();
    push @$ret, (
        no_refs => 1,
        respect_overload => 1,
        message => '',
        indent => 1,
    );

    return $ret;
};

=attr C<message>

A string, which should really only be set via a default in the class
definition. It's used by L</as_string> via
L<NAP::Exception::Formatter>. It's something like a C<printf> format
string.

=cut

has message => (
    is => 'ro',
    required => 1,
);

our $formatter = NAP::Exception::Formatter->new();

=method C<as_string>

Passes the L</message> and the exception object itself to an instance
of L<NAP::Exception::Formatter> (kept in
C<$NAP::Exception::formatter>, but please don't mess with it), and
returns the result.

The object's stringification is overloaded to call this method.

=cut

sub as_string {
    my ($self) = @_;

    return $formatter->format($self->message,$self);
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
