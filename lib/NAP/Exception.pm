package NAP::Exception;
use NAP::policy 'class','overloads';
use NAP::Exception::Formatter;

with 'Throwable';
use overload
  q{""}    => 'as_string',
  fallback => 1;

has message => (
    is => 'ro',
    required => 1,
);

our $formatter = NAP::Exception::Formatter->new();

=method C<as_string>

=cut

sub as_string {
    my ($self) = @_;

    return $formatter->format($self->message,$self);
}
