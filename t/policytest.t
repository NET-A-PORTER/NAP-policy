#!perl
use NAP::policy 'test';

note "1 note";
diag "2 diag";
ok 1;
note "\x{0}\x{1}sò₥ē\x{2603}";
diag "last diag";
done_testing();
