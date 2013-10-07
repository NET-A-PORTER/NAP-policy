package NAP::Exception::FakeStackTrace;
use NAP::policy 'class','tt';

# ABSTRACT: mock object to fake a stack trace

=head1 DESCRIPTION

Don't use this object, see L<NAP::Exception::Role::NoStackTrace>
instead.

=method C<as_string>

returns the empty string

=method C<instance>

returns a singleton instance of this class

=cut

sub as_string { return '' }

sub instance {
    state $instance = __PACKAGE__->new;
    return $instance;
}
