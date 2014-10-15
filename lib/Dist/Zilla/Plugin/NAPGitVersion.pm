package Dist::Zilla::Plugin::NAPGitVersion;
# ABSTRACT: version provider, $nearest_tag-$distance-g$hash
use Dist::Zilla 4 ();
use Moose;
use namespace::autoclean;
use NAP::GitVersion;
with 'Dist::Zilla::Role::VersionProvider';

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

sub provide_version {
    my ($self) = @_;

    return $ENV{V} if exists $ENV{V};

    my $exclude_tags_re = $self->exclude_tags_re;
    my $limit_tags_re = $self->limit_tags_re;
    my $order = $self->order;
    unless (NAP::GitVersion->meta->existing_singleton) {
        NAP::GitVersion->initialize({
            ( defined $exclude_tags_re ? ( exclude_tags_re => $exclude_tags_re ) : () ),
            ( defined $limit_tags_re ? ( limit_tags_re => $limit_tags_re ) : () ),
            ( defined $order ? ( order => $order ) : () ),
        });
    }

    return NAP::GitVersion->instance->perl_style_version_string;
}

__PACKAGE__->meta->make_immutable;
1;
