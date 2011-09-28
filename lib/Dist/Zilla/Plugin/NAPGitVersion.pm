package Dist::Zilla::Plugin::NAPGitVersion;
BEGIN {
  $Dist::Zilla::Plugin::NAPGitVersion::VERSION = '1.00';
}
# ABSTRACT: version provider, $nearest_tag-$distance-g$hash
use Dist::Zilla 4 ();
use Moose;
use namespace::autoclean;
use NAP::GitVersion;
with 'Dist::Zilla::Role::VersionProvider';

=head1 METHODS

=head2 C<provide_version>

Calls to L<NAP::GitVersion> to get version info from the Git log, then
uses C<${tag}_${distance}> as a version (or just C<$tag> if
C<$distance> is 0).

=cut

sub provide_version {
    my ($self) = @_;

    return $ENV{V} if exists $ENV{V};

    my ($tag,$distance,$head) = @{NAP::GitVersion->instance->version_info};

    my $version;
    if ($distance) {
        $version = "${tag}_${distance}";
    }
    else {
        $version = $tag;
    }
    $self->zilla->version($version);
}

__PACKAGE__->meta->make_immutable;
1;
