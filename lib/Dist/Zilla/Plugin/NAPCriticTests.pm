
package Dist::Zilla::Plugin::NAPCriticTests;

# ABSTRACT: tests to check your code against NAP's critic profile

use Moose;
extends 'Dist::Zilla::Plugin::Test::Perl::Critic';
no Moose;
__PACKAGE__->meta->make_immutable;
1;
=head1 SYNOPSIS

In your dist.ini:

    [NAPCriticTests]

=head1 DESCRIPTION

This will create an "author test" file for perl critic testing your distribution
 using NAP's perl critic profile.

Note: author tests don't test anything unless $ENV{AUTHOR_TESTING} is set.

=over 4

=item * t/author/critic.t - test to check your code with NAP critic policy

=back

=for Pod::Coverage gather_files

=head1 SEE ALSO

This module lives in the nap-policy repository.

The original that this was based on

L<http://search.cpan.org/dist/Dist-Zilla-Plugin-Test-Perl-Critic>

=head1 AUTHOR

Jerome Quelin - Dist::Zilla::Plugin::Test::Perl::Critic
Johnathan Swan - hacked into Dist::Zilla::Plugin::NAPCriticTests

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Jerome Quelin.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
___[ xt/author/critic.t ]___
#!perl

use strict;
use warnings;

use NAP::policy; # where you can find NAPCriticTests.pm, which spat this out
use Test::More;
use English qw(-no_match_vars);

eval "use Test::Perl::Critic";
plan skip_all => 'Test::Perl::Critic required to criticise code' if $@;
Test::Perl::Critic->import( -profile => NAP::policy->critic_profile );
all_critic_ok();
