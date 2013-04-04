#!perl
use NAP::policy 'test';
use Perl::Critic;
use Perl::Critic::Document;

sub test_a_policy {
    my ($policy,$failing,$passing) = @_;

    subtest $policy, sub {
        my $critic = Perl::Critic->new(
            '-single-policy' => $policy,
            -verbose => '%L %c <%r>',
            '-program-extensions' => [qw(.PL .pl)],
        );

        my $run_critic = sub {
            if (ref($_[0])) {
                return $critic->critique(Perl::Critic::Document->new(
                    -source => \($_[0]->[0]),
                    '-filename-override' => $_[0]->[1],
                    '-program-extensions' => [$critic->config->program_extensions_as_regexes()],
                ));
            }
            else {
                return $critic->critique(\$_[0]);
            }
        };

        for my $t (@$failing) {
            my @violations = $run_critic->($t);
            #diag $_ for @violations;
            ok(scalar @violations,'expected critic failure');
        }
        for my $t (@$passing) {
            my @violations = $run_critic->($t);
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

test_a_policy 'InputOutput::RequireBriefOpenInModules',
    [
        [q{open my $fh,'<','/tmp/foo',
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
close $fh;},'module.pm'],
    ],
    [
        [q{open my $fh,'<','/tmp/foo',
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
close $fh;},'script.pl'],
        [q{#!perl
open my $fh,'<','/tmp/foo',
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
blah;
close $fh;},'script'],
        [q{open my $fh,'<','/tmp/foo',
blah;
blah;
close $fh;},'script.pl'],
        [q{open my $fh,'<','/tmp/foo',
blah;
blah;
close $fh;},'module.pm'],
    ],
;

done_testing();
