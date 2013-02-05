package PolicyTestMD;
use NAP::policy;

sub test_multid {
    my %a;
    say $a{1,2}; # no multidimensional
}
