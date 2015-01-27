package PolicyTestFH;
use NAP::policy;

sub test_bwfh {
    ## no critic (ProhibitBarewordFileHandles)
    open FOO,'<','/tmp/foo'; # no bareword::filehandle
}
