package NAP::Rpmbuild;
use Moose;
use MooseX::Types::Path::Class qw(Dir File);
use Template;
use NAP::GitVersion;

# ABSTRACT: build an RPM, NAP-style

=head1 SYNOPSIS

  use NAP::Rpmbuild;

  NAP::Rpmbuild->new({
     tarball        => $path_to_your_tarball,
     srcroot        => $work_dir,
     spec_in_file   => $your_spec_template,
     rpm_version    => $your_version,
     rpm_name       => $your_package_name,
  })->build;

=head1 ATTRIBUTES

=head2 C<logger>

Logging sub. Default: nop.

=cut

has logger => (
    is => 'rw',
    isa => 'CodeRef',
    default => sub { sub { } },
);

=head2 C<srcroot>

The directory to work in. RPM subdirs get created under
C<$srcroot/.rpmbuild>, see L</rpmtree>.

=cut

has srcroot => (
    is => 'ro',
    isa => Dir,
    coerce => 1,
    lazy_build => 1,
);
sub _build_srcroot { dir() };

=head2 C<spec_in_file>

TT file to build the specfile from.

=cut

has spec_in_file => (
    is => 'ro',
    isa => File,
    coerce => 1,
    required => 1,
);

=head2 C<tarball>

The tarball to build the RPM from.

=cut

has tarball => (
    is => 'ro',
    isa => File,
    coerce => 1,
    required => 1,
);

=head2 C<tarball_dirname>

The top directory contained in the tarball. Defaults to the basename
of the tarball (minus C<.tar.gz> and the like).

=cut

has tarball_dirname => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);
sub _build_tarball_dirname {
    my $tb = shift->tarball->basename;
    $tb =~ s{\.(tar\.|t)(gz|bz2)$}{};
    return $tb;
}

=head2 C<rpm_version>

Version I<string> to use for the RPM. Not validated, must be a valid
RPM version.

=cut

has rpm_version => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 C<rpm_name>

I<String> to use for the RPM name. Not validated, must be a valid RPM
package name.

=cut

has rpm_name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 C<rpmtree>

Directory where RPM will work (i.e. it contains C<SOURCES>, C<RPMS>,
C<BUILD>, etc subdirs). It will be created as C<$srcroot/.rpmbuild>,
its contents will be wiped, and the needed directories will be
created.

NOTE: can't be set via the constructor.

=cut

has rpmtree => (
    is => 'ro',
    isa => Dir,
    coerce => 1,
    lazy_build => 1,
    init_arg => undef,
);
sub _build_rpmtree {
    my ($self) = @_;

    $self->logger->('preparing rpm dirs');

    my $rpmtree = $self->srcroot->subdir('.rpmbuild');
    $rpmtree->rmtree;

    my $rpmarch = qx{uname -i}; ## no critic (ProhibitBacktickOperators)
    $rpmarch=~s{\s+}{}g;

    for my $subdir (qw(SOURCES RPMS SRPMS BUILD tmp scratch),"RPMS/$rpmarch") {
        $rpmtree->subdir($subdir)->mkpath;
    }

    return $rpmtree;
}

=head2 C<spec_file>

The actual spec file, created from the L</spec_in_file> template.

NOTE: can't be set via the constructor.

TODO: document the template params used.

=cut

has spec_file => (
    is => 'ro',
    isa => File,
    lazy_build => 1,
    init_arg => undef,
);
sub _build_spec_file {
    my ($self) = @_;

    $self->logger->('creating spec file');

    my $file = $self->_create_spec();
    return $file;
}

=head2 C<rpmbuild_cmd>

The command line that will be used to invoke C<rpmbuild>.

NOTE: can't be set via the constructor.

=cut

has rpmbuild_cmd => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
    init_arg => undef,
);
sub _build_rpmbuild_cmd {
    my ($self) = @_;

    my @build_cmd = qw(rpmbuild -bb --clean);

    push @build_cmd,'--define',
        sprintf('VERSION %s',$self->rpm_version);
    push @build_cmd,'--define',
        sprintf('_topdir %s',$self->rpmtree->absolute);
    push @build_cmd,'--define',
        sprintf('_packager %s',(getpwuid($>))[0]);
    push @build_cmd,'--define',
        sprintf('_tmppath %s',$self->tmpdir->absolute);
    push @build_cmd, $self->spec_file->stringify;

    return \@build_cmd;
}

{
my %TEMPLATE_CONFIG = (
    BLOCKS => {
        NAPDIRS => <<'EOF',
%define NAP_BASE_DIR /opt/[% deploydir %]
%define NAP_CONF_DIR /etc/[% sysdir %]
%define NAP_LOGS_DIR /var/log/nap/[% sysdir %]
%define NAP_PID_DIR  /var/run/nap/[% sysdir %]
EOF
        INSTALL => <<'EOF',
rm -rf %{buildroot}
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_BASE_DIR
rsync -al [% dirs.join(' ') %] $RPM_BUILD_ROOT/%NAP_BASE_DIR
echo %{VERSION} > ${RPM_BUILD_ROOT}/%{NAP_BASE_DIR}/VERSION
mkdir -p $RPM_BUILD_ROOT%sysconfdir
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_LOGS_DIR
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_PID_DIR
EOF
        MANIFEST => <<'EOF',
%define manifest %{_builddir}/%{name}-%{version}-%{release}.manifest
cd $RPM_BUILD_ROOT
rm -f %{manifest}
find . -type d ! -path '*/etc/*' \
        | sed '1,2d;s,^\.,\%attr(-\,[%user%]\,[%group%]) \%dir ,' >> %{manifest}
find . -type f ! -path '*/etc/*' \
        | sed 's,^\.,\%attr(-\,[%user%]\,[%group%]) ,' >> %{manifest}
find . -type f -path '*/etc/*' \
        | sed 's,^\.,\%attr(550\,[%user%]\,[%group%]) ,' >> %{manifest}
find . -type l \
        | sed 's,^\.,\%attr(-\,[%user%]\,[%group%]) ,' >> %{manifest}
%files [% IF package; THEN; package _ ' '; END %]-f %{manifest}
%defattr(-,[%user%],[%group%])
EOF
    },
    VARIABLES => {
        REQUIRES_PERL_NAP => <<'EORPN',
Requires: perl-nap >= %( perl -e 'printf "%vd", $^V' )
Requires: perl-nap <  %( perl -MVersion::Next -e 'print (Version::Next::next_version(sprintf "%vd", $^V))' )
EORPN
        SETUP => <<'EOF',
%setup -q -n %{dist_tarball_dir}
EOF
        DEPS => <<'EOMYF',
%{__cat} << 'EOF' > %{name}.prov
#!%{_buildshell}
%{__grep} -v %{_docdir} - |%{__perl} %{__perl_provides} $* \
    | sed -e 's/perl(/perl-nap(/g' \
    | tee -a /tmp/%{name}_provides
EOF
%global __perl_provides %%{_builddir}/%{dist_tarball_dir}/%{name}.prov
%{__chmod} +x %{__perl_provides}
%{__cat} << 'EOF' > %{name}.req
#!%{_buildshell}
%{__grep} -v %{_docdir} - |%{__perl} %{__perl_requires} $* \
    | sed -e 's/perl(/perl-nap(/g' \
    | tee -a /tmp/%{name}_requires
EOF
%global __perl_requires %{_builddir}/%{dist_tarball_dir}/%{name}.req
%{__chmod} +x %{__perl_requires}
EOMYF
        INSTALL => <<'EOF',
rm -rf %{buildroot}
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_BASE_DIR
rsync -al lib scripts conf $RPM_BUILD_ROOT/%NAP_BASE_DIR
echo %{VERSION} > ${RPM_BUILD_ROOT}/%{NAP_BASE_DIR}/VERSION
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_LOGS_DIR
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_PID_DIR
EOF
    },
    RELATIVE => 1,
);
sub _create_spec {
    my ($self) = @_;

    my $spec_in = $self->spec_in_file;

    my $basename = $spec_in->basename;$basename =~ s{\.in$}{};
    my $spec_out = $spec_in->parent->file($basename);
    my $spec_out_fh = $spec_out->openw;

    printf $spec_out_fh "Version: %s\n",
        $self->rpm_version;
    printf $spec_out_fh "Source: %s\n",
        $self->tarball->basename;
    printf $spec_out_fh "BuildRoot: %s\n",
        $self->tmpdir->subdir('%{name}-%{version}-%{release}-build')->absolute;
    printf $spec_out_fh "Name: %s\n",
        $self->rpm_name;
    printf $spec_out_fh "%%define dist_tarball_dir %s\n",
        $self->tarball_dirname;

    my $template = _template();

    $template->process($spec_in->stringify,
                       {},
                       $spec_out_fh,
                       {},
                   )
        || die $template->error();

    close $spec_out_fh;

    return $spec_out;
}

sub _template {
    my $template = Template->new(\%TEMPLATE_CONFIG);
    # backward compatibility for [% MANIFEST %] users; defaulting to
    # nobody/nobody
    # We just process the MANIFEST *block* with the old default values and
    # inject it into the config, then reload with the updated config
    # (there has to be a better way to do this, but for now, we'll go with
    # something that works - CCW)
    my $manifest_blob;
    $template->process(
        \$TEMPLATE_CONFIG{BLOCKS}{MANIFEST},
        { user => 'nobody', group => 'nobody' },
        \$manifest_blob
    );
    $TEMPLATE_CONFIG{VARIABLES}{MANIFEST} = $manifest_blob;
    return Template->new(\%TEMPLATE_CONFIG);
}
}

=head2 C<tmpdir>

C<$rpmtree/tmp>

=cut

sub tmpdir { return shift->rpmtree->subdir('tmp') }

=head2 C<srcdir>

C<$rpmtree/SOURCES>

=cut

sub srcdir { return shift->rpmtree->subdir('SOURCES') }

=head1 METHODS

=head2 C<build>

This will:

=over 4

=item *

create the L</rpmtree> directories

=item *

move the L</tarball> to L</srcdir>

=item *

build the L</spec_file> from the L</spec_in_file>

=item *

create the L</rpmbuild_cmd> command line

=item *

invoke C<rpmbuild>

=back

=cut

sub build {
    my ($self) = @_;

    rename $self->tarball,$self->srcdir->file($self->tarball->basename);

    my $build_cmd = $self->rpmbuild_cmd;
    return system @$build_cmd;
}

1;
