package NAP::Exception::Role::NoStackTrace;
use NAP::policy 'role';
use NAP::Exception::FakeStackTrace;

# ABSTRACT: role to have exceptions I<not> capture the stack

=head1 SYNOPSIS

  package My::Exc::BlewUp {
   use NAP::policy 'exception';
   with 'NAP::Exception::Role::NoStackTrace';

=head1 DESCRIPTION

Some times you don't want to capture the whole stack trace for an
exception, probably because you know that it will be caught just one
or two frames out. In these cases, add this role to your exception
class. The C<stack_trace> argument will still be there, but it will be
C<undef>

=cut

sub _build_stack_trace { return NAP::Exception::FakeStackTrace->instance }
