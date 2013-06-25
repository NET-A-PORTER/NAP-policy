package Dist::Zilla::Plugin::NAPGitVersion;
# ABSTRACT: version provider, $nearest_tag-$distance-g$hash
use Dist::Zilla 4 ();
use Moose;
use namespace::autoclean;
use NAP::GitVersion;
with 'Dist::Zilla::Role::VersionProvider';

=head1 METHODS

=head2 C<provide_version>

Calls to L<NAP::GitVersion/perl_style_version_string> to get
Perl-style version info from the Git log.

=cut

sub provide_version {
    my ($self) = @_;

    return $ENV{V} if exists $ENV{V};

    return NAP::GitVersion->instance->perl_style_version_string;
}

__PACKAGE__->meta->make_immutable;
1;
