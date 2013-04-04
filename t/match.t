#!perl
use strict;
use warnings;
use lib 't/lib';
use Test::Most;

BEGIN { use_ok 'PolicyTestMatch' }

is(PolicyTestMatch::foo(bless {},'foo'),'class','smart match 1');
is(PolicyTestMatch::foo(12),'number','smart match 2');
is(PolicyTestMatch::foo('blah'),'whatever','smart match 3');

done_testing();
