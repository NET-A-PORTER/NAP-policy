package NAP::GitVersion;
# ABSTRACT: function to get $nearest_tag-$distance-g$hash
use Moose;
use MooseX::Singleton;
use Git::Wrapper 0.020;
use version ();
use 5.014;
use namespace::autoclean;

=head1 SYNOPSIS

  use NAP::GitVersion;

  my ($nearest_tag,$distance,$head_commit) =
     NAP::GitVersion->instance->version_info();

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

=head2 C<version_info>

Cached version information extracted from Git. A 3-element array ref:

=over 4

=item 0Z<>

The nearest tag (or C<0.0> if no tag was found)

=item 1Z<>

The distance (0 means the tag is at HEAD)

=item 2Z<>

The abbreviated commit hash for HEAD

=back

=cut

has version_info => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
);

sub _build_version_info {
    my ($self) = @_;
    return $ENV{V} if exists $ENV{V};

    my $git  = Git::Wrapper->new($self->git_dir);
    my @commits =
        map { m{^([a-f0-9]+) \x00 (.*?) \x00 }ix ? [ $1, _parse_tag($2) ] : () }
            $git->RUN(log => {
                topo_order => 1,
                decorate => 'full',
                pretty => 'format:%h%x00%d%x00',
            },'HEAD');
    my $head = $commits[0]->[0];

    my ($distance,$tag)=(0,'0.0');
    for my $c (@commits) {
        if (@$c > 1) {
            shift @$c;
            my @tags = grep { ! /^(?:release|jenkins)-/ } @$c;
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
