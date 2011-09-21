package Dist::Zilla::App::Command::rpmbuild;
use Dist::Zilla::App -command;
use Path::Class;
use Template;
use Moose;
use NAP::GitVersion;
use NAP::Rpmbuild;

# ABSTRACT: build an RPM, NAP-style

has tarball => (
    is => 'ro',
    lazy_build => 1,
);
sub _build_tarball {
    my ($self) = @_;
    $self->log('building');
    my $tarball = file($self->zilla->build_archive);
    $self->log("built to $tarball");
    return $tarball;
}

has rpm_version => (
    is => 'ro',
    lazy_build => 1,
);
sub _build_rpm_version {
    my ($self) = @_;
    my ($tag,$distance,$head) = @{NAP::GitVersion->instance->version_info};
    my $version = $distance ? "${tag}.${distance}.g${head}" : $tag;
    return $version;
}

sub abstract { 'build an RPM, NAP-style' }

sub execute {
    my ($self, $opt, $args) = @_;

    my $tarball = $self->tarball;

    my ($spec_in) = grep { m{\.spec\.in$} } $self->zilla->root->children;
    die "No *.spec.in file!\n" unless $spec_in;

    my $builder = NAP::Rpmbuild->new({
        logger => sub { $self->log(@_) },
        srcroot => $self->zilla->root,
        spec_in_file => $spec_in,
        tarball => $tarball,
        rpm_version => $self->rpm_version,
        rpm_name => $self->zilla->name,
    });

    $builder->build;
}

1;
