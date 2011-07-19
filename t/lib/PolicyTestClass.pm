package PolicyTestClass;{
use NAP::policy 'class';

with 'PolicyTestRole';

has foo => ( is => 'ro' );
}

package PolicyTestClass2;{
use NAP::policy 'class';

has baz => ( is => 'ro' );
}
