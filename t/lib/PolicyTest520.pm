package PolicyTest520;
use NAP::policy;

sub postderef { return $_[1]->@* }
sub hash_slice { return $_[1]->%{qw(a b)} }
