package PolicyTest;
use NAP::policy 'exporter';

# testing all pieces of the policy:

use Sub::Exporter -setup => {
    exports => [ 'foo' ],
};

sub foo {
    try { # TryCatch
        my $a;
        say $a; # 5.12 & warnings FATAL
        carp "ok"; # Carp
    }
    catch ($e) {
        carp "not ok - $e";
    }
}

# true
