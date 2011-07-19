#!perl
use NAP::policy 'test';
use File::Find::Rule;
use Perl::Critic;

my @files = File::Find::Rule
    ->file()
    ->name( qr/\.(t|pl|pm)$/ )
    ->in( 'lib' );

my $profile = NAP::policy->critic_profile();
note "using $profile";
my $critic = Perl::Critic->new(
    -severity => 'stern',
    -profile  => $profile,
);

note(scalar(@files) . " files to test");

Perl::Critic::Violation::set_format('%m at line %l, column %c. %e (from %p)');

for my $file (sort @files) {
    my @violations = $critic->critique( $file );
    if (@violations) {
        fail("Perl Critic violations found in $file");
        diag( $_->to_string ) for @violations;
    } else {
        pass("No Perl Critic violations found in $file");
    }
}

done_testing;
