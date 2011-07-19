#!perl
use strict;
use warnings;
use lib 't/lib';
use Test::Most;
# Test::Output plays weird tricks with 'warnings FATAL', so I write my
# own version below
# use Test::Output;

BEGIN { use_ok 'PolicyTest' }

{
my ($outstr,$errstr)=('','');
{
open my $outfh,'>',\$outstr;
open my $errfh,'>',\$errstr;
local *STDOUT=$outfh;
local *STDERR=$errfh;
PolicyTest::foo();
}
is($outstr,'','no stdout');
like($errstr,qr{^not ok -},'all modules worked');
}
ok(PolicyTest->can('import'),'exporter is preserved');

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

ok(-f NAP::policy->critic_profile,
   'the Perl::Critic profile is returned');

done_testing();
