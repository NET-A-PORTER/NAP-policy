#!perl
use NAP::policy 'test';
use Perl::Critic;

sub test_a_policy {
    my ($policy,$failing,$passing) = @_;

    subtest $policy, sub {
        my $critic = Perl::Critic->new(
            '-single-policy' => $policy,
            -verbose => '%L %c <%r>',
        );

        for my $t (@$failing) {
            my @violations = $critic->critique(\$t);
            #diag $_ for @violations;
            ok(scalar @violations,'expected critic failure');
        }
        for my $t (@$passing) {
            my @violations = $critic->critique(\$t);
            diag $_ for @violations;
            ok(scalar @violations==0,'critic pass');
        }
    };
}

test_a_policy 'CodeLayout::Require7bitIds',
    [
        q{package Fóo;},
        q{my $fóo=1},
        q{sub fóo { } },
        q{$call->mə()},
        q{$call->me(mə=>1)},
    ],
    [
        q{my $foo='fóò'},
        q{
sub foo { # çó₥ḿēñţ
}
},
        q{$call->me('mə'=>1)},
    ],
;

test_a_policy 'Modules::RequireTrue',
    [
        q{package Foo;},
        q{package Foo;0;},
    ],
    [
        q{package Foo;1;},
        q{package Foo;use true;},
        q{package Foo;use NAP::policy;},
    ],
;

done_testing();
