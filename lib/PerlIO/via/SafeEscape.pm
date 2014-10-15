package PerlIO::via::SafeEscape;
use strict;
use warnings;
use 5.018;
use Encode;

# ABSTRACT: IO layer to escape unprintable characters

=head1 SYNOPSIS

  binmode STDOUT, ':raw:via(SafeEscape)';

=head1 DESCRIPTION

Applying this IO layer to an output filehandle will replace each
unprintable characters with a C<\x{...}> style string, using the
character's codepoint in base 16.

Don't apply this layer to input filehandles, it will most probably
fail in bad ways.

This layer assumes it's getting I<characters>. If you send random
bytes, you'll probably get strange outputs.

=for Pod::Coverage
PUSHED
UTF8
FLUSH
FILL
WRITE

=cut

# PUSHED is essentially a constructor; we don't need to have a real
# instance, so just return a empty singleton
my $instance = bless do{my $x = 0;\$x},__PACKAGE__;
sub PUSHED { return $instance }

# we want characters!
sub UTF8 { 1 }

# a weak attempt at working for input
sub FILL { return readline($_[1]) }

# without this, autoflush is not propagated down!
sub FLUSH { return $_[1]->flush }

# the actual output function
sub WRITE {
    my (undef,$buf,$fh) = @_;

    # we should return the number of bytes written, so let's save it
    my $ret = length($buf);

    # $buf is utf-8 encoded bytes, let's get the characters
    my $char_buf = decode('utf-8',$buf);
    # not printable, not space? escape it!
    $char_buf =~ s{([^[:print:][:space:]])}{sprintf '\x{%x}',ord($1)}ge;
    # we have to pass bytes to the next layer
    $buf = encode('utf-8',$char_buf);

    return ( $fh->print($buf) ? $ret : -1 );
}

1;
