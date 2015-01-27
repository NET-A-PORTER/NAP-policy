package Dist::Zilla::App::Command::rpmbuild;
use Dist::Zilla::App -command;
use Path::Class;
use Template;
use Moose;
use NAP::GitVersion;
use NAP::Rpmbuild;
use List::MoreUtils 'any';
use Moose::Autobox 0.09; # ->flatten

# ABSTRACT: build an RPM, NAP-style

sub opt_spec {
    [ 'spec-file|f=s' => 'spec template file to use, defaults to the only .spec.in it finds' ],
}

has tarball => (
    is => 'ro',
    lazy_build => 1,
);
sub _build_tarball {
    my ($self) = @_;
    $self->log('building tarball');
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

    # are we using our own version provider?
    if (any { $_->isa('Dist::Zilla::Plugin::NAPGitVersion') }
            $self->zilla->plugins_with(-VersionProvider)->flatten ) {
        return NAP::GitVersion->instance->rpm_style_version_string;
    }
    else {
        return $self->zilla->version;
    }
}

sub abstract { 'build an RPM, NAP-style' }

sub execute {
    my ($self, $opt, $args) = @_;

    my $spec_in = $opt->spec_file;
    unless ($spec_in) {
        my @candidates = grep { m{\.spec\.in$} } $self->zilla->root->children;
        die "Multiple spec file templates found: @candidates. Please use the --spec-file option to select one\n"
            if @candidates > 1;
        die "No *.spec.in file!\n"
            if @candidates == 0;
        $spec_in = $candidates[0];
    }
    die "Spec template file $spec_in does not exist!\n"
        unless -e $spec_in;
    die "The name of spec template file $spec_in should end in .spec.in\n"
        unless $spec_in =~ m{\.spec\.in$};

    my $tarball = $self->tarball;

    my $builder = NAP::Rpmbuild->new({
        logger => sub { $self->log(@_) },
        srcroot => $self->zilla->root,
        spec_in_file => $spec_in,
        tarball => $tarball,
        rpm_version => $self->rpm_version,
        rpm_name => $self->zilla->name,
    });

    $builder->build;

    return;
}

1;
