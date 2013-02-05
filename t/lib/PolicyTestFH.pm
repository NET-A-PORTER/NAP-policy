package PolicyTestFH;
use NAP::policy;

sub test_bwfh {
    open FOO,'<','/tmp/foo'; # no bareword::filehandle
}
