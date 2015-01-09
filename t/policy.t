#!perl
use strict;
use warnings;
use lib 't/lib';
use Test::Most;
# Test::Output plays weird tricks with 'warnings FATAL', so I write my
# own version below
# use Test::Output;

BEGIN { use_ok 'PolicyTest' }

sub capture(&) {
    my ($code) = @_;

    my ($outstr,$errstr)=('','');
    {
        open my $outfh,'>',\$outstr;
        open my $errfh,'>',\$errstr;
        local *STDOUT=$outfh;
        local *STDERR=$errfh;
        $code->();
    }
    return ($outstr,$errstr);
}

{
    my ($outstr,$errstr)=capture { PolicyTest::foo() };
    is($outstr,'','no stdout');
    like($errstr,qr{^not ok -},'most modules worked');
}

{
    eval "require PolicyTestMD;";my $err = $@;
    like($err,qr{^Use of multidimensional array emulation},'no multidimensional worked');
}

{
    eval "require PolicyTestFH;";my $err = $@;
    like($err,qr{^Use of bareword filehandle in open},'no bareword::filehandle worked');
}

ok(PolicyTest->can('import'),'exporter is preserved');
ok(PolicyTest->can('carp'),'carp is preserved');

warnings_like { eval "use PolicyTestWarn" }
    [ { carped => qr{^ignoring dont_clean option without arrayref\b} },
      { carped => qr{^ignoring unknown import option 'badopt'} },
  ],'correct warnings on bad options';

use_ok 'PolicyTestClass';

my $p = PolicyTestClass->new({foo=>1,bar=>2});
isa_ok($p,'PolicyTestClass');
is($p->foo(),1,'accessor from class');
is($p->bar(),2,'accessor from role');
ok(!PolicyTestClass->can('has'),'namespace::autoclean worked');
ok(!PolicyTestClass->meta->is_mutable(),'class is immutable');

$p = PolicyTestClass2->new({baz=>3});
is($p->baz(),3,'accessor from second class in file');
ok(!PolicyTestClass2->can('has'),'namespace::autoclean worked');
ok(!PolicyTestClass2->meta->is_mutable(),'second class is immutable');

use_ok 'PolicyTestTryTiny';
is(PolicyTestTryTiny->foo(),'ok','Try::Tiny works');
throws_ok { PolicyTestTryTiny->foo('bad') }
    qr{^bad\b},
    'Try::Tiny re-throw works';

ok(-f NAP::policy->critic_profile,
   'the Perl::Critic profile is returned');

if ($^V ge v5.20) {
    use_ok 'PolicyTest520';

    my $aref = [1,2,3];
    my @list = PolicyTest520->postderef($aref);
    cmp_deeply(\@list,$aref,'postderef ok');

    my $href = { a => 1, b => 2, c => 3 };
    my %hash = PolicyTest520->hash_slice($href);
    cmp_deeply(\%hash,{a=>1,b=>2},'hash slice ok');
}

done_testing();
