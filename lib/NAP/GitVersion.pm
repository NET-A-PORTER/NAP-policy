package NAP::GitVersion;
# ABSTRACT: function to get $nearest_tag-$distance-g$hash
use Moose;
use MooseX::Singleton;
use Moose::Util::TypeConstraints 'enum';
use Git::Wrapper 0.020;
use version ();
use 5.014;
use namespace::autoclean;

=head1 SYNOPSIS

  use NAP::GitVersion;

  my ($nearest_tag,$distance,$head_commit) =
     @{NAP::GitVersion->instance->version_info};

=head1 DESCRIPTION

This singleton parses the Git log to extract the nearest tag, how many
commits HEAD is distant from it, and the (abbreviated) commit hash of
HEAD.

=head1 ATTRIBUTES

=head2 C<git_dir>

Defaults to the current directory. To set it, call:

  NAP::GitVersion->_clear_instance;
  NAP::GitVersion->initialize(git_dir => $your_dir);

=cut

has git_dir => (
    is => 'ro',
    isa => 'Str',
    default => '.',
);

=head2 C<exclude_tags_re>

Regex matching tags we want to ignore. Defaults to
C<^(?:release|jenkins)->.To set it, call:

  NAP::GitVersion->_clear_instance;
  NAP::GitVersion->initialize(exclude_tags_re => $your_re);

=cut

has exclude_tags_re => (
    is => 'ro',
    isa => 'Str',
    default => '^(?:release|jenkins)-',
);

=head2 C<limit_tags_re>

Regex matching only the tags we want to use. Defaults to C<.>
(i.e. every non-empty tag).To set it, call:

  NAP::GitVersion->_clear_instance;
  NAP::GitVersion->initialize(limit_tags_re => $your_re);

=cut

has limit_tags_re => (
    is => 'ro',
    isa => 'Str',
    default => '.',
);

=head2 C<order>

What order to consider commits in, to get the "closest" tag. Defaults
to C<topo>, can be set to C<date>. See the C<git-log> man page for the
precise meaning of C<--topo-order> and C<--date-order>. To set this
attribute, call:

  NAP::GitVersion->_clear_instance;
  NAP::GitVersion->initialize(order => 'date');

=cut

has order => (
    is => 'ro',
    isa => enum(['topo','date']),
    default => 'topo',
);

=head2 C<version_info>

Cached version information extracted from Git. A 3-element array ref:

=over 4

=item 0Z<>

The nearest tag (or C<0.0> if no tag was found).
The shortest matching tag is returned if there are multiple tags on
the same commit.

=item 1Z<>

The distance (0 means the tag is at HEAD)

=item 2Z<>

The abbreviated commit hash for HEAD

=back

Tags matching L</exclude_tags_re> or not matching L</limit_tags_re>
are skipped.

=cut

has version_info => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
);

sub _build_version_info {
    my ($self) = @_;

    my $git  = Git::Wrapper->new($self->git_dir);
    my $order = $self->order;
    my @commits =
        map { m{^([a-f0-9]+) \x00 (.*?) \x00 }ix ? [ $1, _parse_tag($2) ] : () }
            $git->RUN(log => {
                "${order}_order" => 1,
                decorate => 'full',
                pretty => 'format:%h%x00%d%x00',
            },'HEAD');
    my $head = $commits[0]->[0];

    return [$ENV{V},0,$head] if exists $ENV{V};

    my ($distance,$tag)=(0,'0.0');
    my $exclude_tags_re = $self->exclude_tags_re;$exclude_tags_re=qr{$exclude_tags_re};
    my $limit_tags_re = $self->limit_tags_re;$limit_tags_re=qr{$limit_tags_re};
    for my $c (@commits) {
        if (@$c > 1) {
            shift @$c;
            my @tags = sort { length($a) <=> length($b) }
                grep { ! /$exclude_tags_re/o && /$limit_tags_re/o } @$c;
            if ($tags[0]) {
                $tag=$tags[0];
                last;
            }
        }
        ++$distance;
    }

    return [$tag,$distance,$head];
}

sub _parse_tag {
    my ($refs) = @_;
    return unless defined $refs;
    my @tags = map { m{refs/tags/(.*)} }
        split /\s*,\s*/,
            $refs =~ s{^\s*\(|\)\s*$}{}gr;
    return @tags;
}

=head1 METHODS

=head2 C<nearest_tag>

=head2 C<tag_distance>

=head2 C<commit_hash>

Utility accessors for the three elements of L</version_info>

=cut

sub nearest_tag  { shift->version_info->[0] }
sub tag_distance { shift->version_info->[1] }
sub commit_hash  { shift->version_info->[2] }

=head2 C<perl_style_version_string>

Returns C<${tag}_${distance}> (or just C<$tag> if C<$distance> is
0). If the tag does not look like a Perl version number (acconding to
L<version/is_lax>), it will only use a likely-looking prefix (or '0.0'
if there is no sensible prefix).

=cut

sub perl_style_version_string {
    my ($self) = @_;
    state $clean_version_rx = qr{
                                    [0-9]+ (?: [.] [0-9]+ )+
                            }x;

    my ($tag,$distance,$head) = @{$self->version_info};

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

=head2 C<rpm_style_version_string>

Returns C<${tag}.${distance}.g${commit}> (or just C<$tag> if
C<$distance> is 0).

=cut

sub rpm_style_version_string {
    my ($self) = @_;

    my ($tag,$distance,$head) = @{$self->version_info};
    return $distance ? "${tag}.${distance}.g${head}" : $tag;
}

1;
