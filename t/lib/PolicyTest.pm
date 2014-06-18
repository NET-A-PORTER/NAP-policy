package PolicyTest;
use NAP::policy dont_clean=>['carp'],'exporter';
use Carp;

# testing all pieces of the policy:

use Sub::Exporter -setup => {
    exports => [ 'foo' ],
};

sub foo {
    try { # Try::Tiny
        my $a;
        say $a; # 5.12 & warnings FATAL
        carp "ok"; # Carp
    }
    catch {
        carp "not ok - $_";
    };
}

# true
