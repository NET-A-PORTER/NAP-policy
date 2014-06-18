package PolicyTestTryTiny;
use NAP::policy;

sub foo {
    my ($class,$arg) = @_;
    my $ret='fail';
    try {
        if ($arg) {
            die "bad";
        }
        else {
            die bless {},'MyException';
        }
    }
    catch {
        when (match_instance_of('MyException')) {
            $ret="ok"
        }
        default { die $_ }
    };
    return $ret;
}
