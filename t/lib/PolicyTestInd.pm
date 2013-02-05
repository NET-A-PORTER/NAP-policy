package PolicyTestInd;
use NAP::policy;

package MyTest { sub new { } };

sub test_indirect {
    my $a = new MyTest(); # no indirect
}
