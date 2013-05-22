package Dist::Zilla::Plugin::NAPGitVersion;
# ABSTRACT: version provider, $nearest_tag-$distance-g$hash
use Dist::Zilla 4 ();
use Moose;
use version ();
use namespace::autoclean;
use NAP::GitVersion;
with 'Dist::Zilla::Role::VersionProvider';

=head1 METHODS

=head2 C<provide_version>

Calls to L<NAP::GitVersion> to get version info from the Git log, then
uses C<${tag}_${distance}> as a version (or just C<$tag> if
C<$distance> is 0). If the tag does not look like a Perl version
number (acconding to L<version/is_lax>), it will only use a
likely-looking prefix (or '0.0' if there is no sensible prefix).

=cut

my $clean_version_rx = qr{
  [0-9]+ (?: [.] [0-9]+ )+
}x;

sub provide_version {
    my ($self) = @_;

    return $ENV{V} if exists $ENV{V};

    my ($tag,$distance,$head) = @{NAP::GitVersion->instance->version_info};

    if (not version::is_lax($tag)) {
        ($tag) = $tag =~ m{\A ($clean_version_rx) }x;
        $tag //= '0.0';
    }

    my $version;
    if ($distance) {
        $version = "${tag}_${distance}";
    }
    else {
        $version = $tag;
    }
    return $version;
}

__PACKAGE__->meta->make_immutable;
1;
