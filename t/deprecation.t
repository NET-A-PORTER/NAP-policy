#!perl
use strict;
use warnings;
use Test::Most;

warnings_like { eval <<'PACK' }
package Foo {
use NAP::policy 'exporter';
use Sub::Exporter -setup => { exports => [ 'foo' ] };
sub foo {}
}
PACK
[ {carped => qr{no need to specify 'exporter' anymore.* at \(eval } } ],
    'deprecated "exporter"';
ok(Foo->can('import'),'"import" not cleaned');

warnings_like { eval <<'PACK' }
package Foo2 {
use NAP::policy 'exporter';
use Sub::Exporter -setup => { exports => [ 'foo' ] };
sub foo {}
}
PACK
[ ],
    'deprecations listed only once per process';
ok(Foo2->can('import'),'"import" not cleaned');

done_testing();
