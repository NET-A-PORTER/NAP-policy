package Dist::Zilla::Plugin::NAPGitVersion;
# ABSTRACT: version provider, $nearest_tag-$distance-g$hash
use Dist::Zilla 4 ();
use Moose;
use namespace::autoclean;
use NAP::GitVersion;
with 'Dist::Zilla::Role::VersionProvider',
    'Dist::Zilla::Role::ReleaseStatusProvider';

=head1 ATTRIBUTES

=head2 C<exclude_tags_re>

Regex matching tags we want to ignore. Defaults to
C<^(?:release|jenkins)-> in L<NAP::GitVersion>.

=cut

has exclude_tags_re => (
    is => 'ro',
    isa => 'Str',
);

=head2 C<limit_tags_re>

Regex matching only the tags we want to use. Defaults to C<.>
(i.e. every non-empty tag) in L<NAP::GitVersion>.

=cut

has limit_tags_re => (
    is => 'ro',
    isa => 'Str',
);

=head2 C<order>

What order to consider commits in, to get the "closest" tag. Defaults
to C<topo> (in L<NAP::GitVersion>), can be set to C<date>. See the
C<git-log> man page for the precise meaning of C<--topo-order> and
C<--date-order>.

=cut

has order => (
    is => 'ro',
    isa => 'Str',
);

=head1 METHODS

=head2 C<provide_version>

Calls to L<NAP::GitVersion/perl_style_version_string> to get
Perl-style version info from the Git log.

=cut

sub _get_gitversion {
    my ($self) = @_;

    unless (NAP::GitVersion->meta->existing_singleton) {
        my $exclude_tags_re = $self->exclude_tags_re;
        my $limit_tags_re = $self->limit_tags_re;
        my $order = $self->order;
        NAP::GitVersion->initialize({
            ( defined $exclude_tags_re ? ( exclude_tags_re => $exclude_tags_re ) : () ),
            ( defined $limit_tags_re ? ( limit_tags_re => $limit_tags_re ) : () ),
            ( defined $order ? ( order => $order ) : () ),
        });
    }

    return NAP::GitVersion->instance;
}

sub provide_version {
    my ($self) = @_;

    return $ENV{V} if exists $ENV{V};

    return $self->_get_gitversion->perl_style_version_string;
}

=head2 C<provide_release_status>

Calls to L<NAP::GitVersion/tag_distance> to see if we are building on
a tag.  Returns C<'stable'> if we are, C<'testing'> otherwise. This
makes sure that all our metadata is consistent.

=cut

sub provide_release_status {
    my ($self) = @_;

    # if a version is provided via the environment, let dzil sort it out
    return if exists $ENV{V};

    # otherwise, we are stable if we're building on a tag
    return $self->_get_gitversion->tag_distance > 0 ? 'testing' : 'stable';
}

__PACKAGE__->meta->make_immutable;
1;
