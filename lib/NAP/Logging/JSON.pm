package NAP::Logging::JSON;
use NAP::policy 'exporter','class','tt','overloads';
use overload
    '""' => \&to_string,
    '%{}' => \&as_hashref,
    fallback => 1;
use Tie::IxHash;
use JSON::Any;
use Sub::Exporter -setup => {
    exports => [ 'logmsg' ],
    groups => { default => [ 'logmsg' ] },
};

# ABSTRACT: structured logging object, stringifies as JSON

=head1 SYNOPSIS

  use NAP::Logging::JSON;

  $logger->info(logmsg 'doing something', record => 123, op => 'update');

Will log something like:

  [info] { "message":"doing something", "record":123, "op":"update" }

=head1 DESCRIPTION

This module is a re-implementation of L<Log::Message::JSON>, with
simpler internals. It allows you to pass an object to your logging
system, that will behave as a hashref or as a JSON string, depending
on the capabilities of your loggers.

=head1 EXPORTED FUNCTIONS

=head2 C<logmsg>

Just an alias for C<< NAP::Logging::JSON->new >>. You can change the
name of this function at import time:

  use NAP::Logging::JSON logmsg => { -as => 'logjson' };

See L<Sub::Exporter> for details.

=cut

sub logmsg {
    return __PACKAGE__->new(@_);
}

=head1 CONSTRUCTOR

You can construct objects of this class in our ways:

=over 4

=item C<< NAP::Logging::JSON->new(\%hash) >>

Will just set L</data> to the hashref passed in.

=item C<< NAP::Logging::JSON->new(%hash) >>

Will set L</data> to a hashref tied to L<Tie::IxHash>, so that the
attributes will be serialised in the same order as you provided them.

=item C<< NAP::Logging::JSON->new('string') >>

Same as C<< NAP::Logging::JSON->new(message => 'string') >>.

=item C<< NAP::Logging::JSON->new('string', %hash) >>

Same as C<< NAP::Logging::JSON->new(message => 'string', %hash) >>.

=back

=cut

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;

    if (@args == 1 and ref($args[0])) { # new(\%hash)
        return $class->$orig({data=>$args[0]});
    }
    elsif (@args % 2 == 1) { # new('string',%hash) or new('string')
        tie my %ixhash,'Tie::IxHash', message => @args;
        return $class->$orig({data=>\%ixhash});
    }
    else { # new(%hash)
        tie my %ixhash,'Tie::IxHash', @args;
        return $class->$orig({data=>\%ixhash});
    }
};

=attr C<data>

A hashref, set by the constructor.

=cut

has data => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

=method C<as_hashref>

Returns the contents of L</data>. Used for overloading.

=cut

sub as_hashref {
    my ($self) = @_;

    # we have to skip the overload from inside our own code, otherwise
    # we recurse when executing our own accessors
    return $self if caller eq __PACKAGE__;
    return $self if caller =~ m{\A (?: Moose | Class::MOP | Eval::Closure) \b}x;
    return $self->data;
}

=method C<to_string>

Returns a JSON string with the contents of L</data>. Used for overloading.

=cut

my $json = JSON::Any->new(canonical=>1);

sub to_string {
    return $json->encode($_[0]->data);
}

=head1 OVERLOADING

This class overloads hash derefence (via L</as_hashref>) and
stringification (via L</to_string>).

=cut
