package NAP::GitVersion;
# ABSTRACT: function to get $nearest_tag-$distance-g$hash
use Moose;
use MooseX::Singleton;
use Git::Wrapper 0.020;
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

=item 0

The nearest tag (or C<0.0> if no tag was found)

=item 1

The distance (0 means the tag is at HEAD)

=item 2

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
        if ($c->[1]) {
            $tag=$c->[1];
            last;
        }
        ++$distance;
    }

    return [$tag,$distance,$head];
}

sub _parse_tag {
    my ($refs) = @_;
    return '' unless defined $refs;
    my ($tag) = ($refs =~ m{refs/tags/(.*?)[,)]});
    return '' unless $tag;
    return $tag;
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

1;
