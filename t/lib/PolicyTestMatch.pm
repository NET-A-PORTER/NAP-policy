package PolicyTestMatch;
# we import 'tt' to check that the default import of match_instance_of
# does not conflict with importing the rest of Smart::Match
use NAP::policy 'tt','match';

sub foo {
    given(shift) {
        when (match_instance_of('foo')) { return 'class' }
        when (match_number) { return 'number' }
        default { return 'whatever' }
    }
}
