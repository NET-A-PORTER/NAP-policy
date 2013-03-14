package PolicyTestTryTiny;
use NAP::policy 'tt';

sub foo {
    my $ret='fail';
    try {
        die "ok\n";
    }
    catch {
        $ret="ok" if $_ eq "ok\n";
    };
    return $ret;
}
