package NAP::Exception::FakeStackTrace;
use NAP::policy 'class','tt';

# ABSTRACT: mock object to fake a stack trace

=head1 DESCRIPTION

Don't use this object, see L<NAP::Exception::Role::NoStackTrace>
instead.

=method C<as_string>

returns the empty string

=cut

sub as_string { return '' }
