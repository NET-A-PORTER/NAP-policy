package Dist::Zilla::App::Command::rpmbuild;
use Dist::Zilla::App -command;
use Path::Class;
use Template;

# ABSTRACT: build an RPM, NAP-style

sub abstract { 'build an RPM, NAP-style' }

sub execute {
    my ($self, $opt, $args) = @_;

    $self->log('building');

    my $tarball = file($self->zilla->build_archive);

    $self->log("built to $tarball");

    $self->{_tarballname} = $tarball->basename;

    $self->log('preparing rpm dirs');

    $self->{_rpmtree} = $self->_create_rpmdirs;

    $self->log('preparing spec file');

    $self->{_specfile} = $self->_create_spec;

    rename $tarball,$self->_srcdir->file($self->{_tarballname});

    my @build_cmd = $self->_build_rpmbuild_cmd;

    $self->log('calling rpmbuild');

    system @build_cmd;
}

sub _create_rpmdirs {
    my ($self) = @_;

    my $rpmtree = $self->zilla->root->subdir('.rpmbuild');
    $rpmtree->rmtree;

    my $rpmarch = qx{uname -i};$rpmarch=~s{\s+}{}g;

    for my $subdir (qw(SOURCES RPMS SRPMS BUILD tmp scratch),"RPMS/$rpmarch") {
        $rpmtree->subdir($subdir)->mkpath;
    }

    return $rpmtree;
}

{
my %TEMPLATE_CONFIG = (
    BLOCKS => {
        NAPDIRS => <<'EOF',
%define NAP_BASE_DIR /opt/xt/deploy/[% deploydir %]
%define NAP_CONF_DIR /etc/[% sysdir %]
%define NAP_LOGS_DIR /var/log/nap/[% sysdir %]
%define NAP_PID_DIR  /var/run/nap/[% sysdir %]
EOF
    },
    VARIABLES => {
        MANIFEST => <<'EOF',
%define manifest %{_builddir}/%{name}-%{version}-%{release}.manifest
cd $RPM_BUILD_ROOT
rm -f %{manifest}
find . -type d ! -path '*/etc/*' \
        | sed '1,2d;s,^\.,\%attr(-\,nobody\,nobody) \%dir ,' >> %{manifest}
find . -type f ! -path '*/etc/*' \
        | sed 's,^\.,\%attr(-\,nobody\,nobody) ,' >> %{manifest}
find . -type f -path '*/etc/*' \
        | sed 's,^\.,\%attr(550\,nobody\,nobody) ,' >> %{manifest}
find . -type l \
        | sed 's,^\.,\%attr(-\,nobody\,nobody) ,' >> %{manifest}
%files -f %{manifest}
%defattr(-,nobody,nobody)
EOF
        DEPS => <<'EOMYF',
%{__cat} << 'EOF' > %{name}.prov
#!%{_buildshell}
%{__grep} -v %{_docdir} - |%{__perl} %{__perl_provides} $* \
    | sed -e 's/perl(/perl-nap(/g' \
    | tee -a /tmp/%{name}_provides
EOF
%global __perl_provides %%{_builddir}/%{name}-%{version}/%{name}.prov
%{__chmod} +x %{__perl_provides}
%{__cat} << 'EOF' > %{name}.req
#!%{_buildshell}
%{__grep} -v %{_docdir} - |%{__perl} %{__perl_requires} $* \
    | sed -e 's/perl(/perl-nap(/g' \
    | tee -a /tmp/%{name}_requires
EOF
%global __perl_requires %{_builddir}/%{name}-%{version}/%{name}.req
%{__chmod} +x %{__perl_requires}
EOMYF
        INSTALL => <<'EOF',
rm -rf %{buildroot}
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_BASE_DIR
rsync -al lib scripts conf $RPM_BUILD_ROOT/%NAP_BASE_DIR
echo %{VERSION} > ${RPM_BUILD_ROOT}/%{NAP_BASE_DIR}/VERSION
mkdir -p $RPM_BUILD_ROOT%sysconfdir
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_LOGS_DIR
install -m 0755 -d $RPM_BUILD_ROOT/%NAP_PID_DIR
EOF
    },
);
sub _create_spec {
    my ($self) = @_;

    my ($spec_in) = grep { m{\.spec\.in$} } $self->zilla->root->children;

    die "No *.spec.in file!\n" unless $spec_in;

    my $spec_in_fh = $spec_in->openr;
    my $basename = $spec_in->basename;$basename =~ s{\.in$}{};
    my $spec_out = $spec_in->parent->file($basename);
    my $spec_out_fh = $spec_out->openw;

    printf $spec_out_fh "Version: %s\n",
        $self->zilla->version;
    printf $spec_out_fh "Source: %s\n",
        $self->{_tarballname};
    printf $spec_out_fh "BuildRoot: %s\n",
        $self->_tmpdir->subdir('%{name}-%{version}-%{release}-build')->absolute;
    printf $spec_out_fh "Name: %s\n",
        $self->zilla->name;

    my $template = Template->new(\%TEMPLATE_CONFIG);
    $template->process($spec_in_fh,
                       {},
                       $spec_out_fh,
                       {},
                   )
        || die $template->error();

    close $spec_in_fh;close $spec_out_fh;

    return $spec_out;
}
}

sub _build_rpmbuild_cmd {
    my ($self) = @_;

    my @build_cmd = qw(rpmbuild -bb --clean);

    push @build_cmd,'--define',
        sprintf('VERSION %s',$self->zilla->version);
    push @build_cmd,'--define',
        sprintf('_topdir %s',$self->{_rpmtree}->absolute);
    push @build_cmd,'--define',
        sprintf('_packager %s',(getpwuid($>))[0]);
    push @build_cmd,'--define',
        sprintf('_tmppath %s',$self->_tmpdir->absolute);
    push @build_cmd, $self->{_specfile}->stringify;

    return @build_cmd;
}

sub _tmpdir { return shift->{_rpmtree}->subdir('tmp') }
sub _srcdir { return shift->{_rpmtree}->subdir('SOURCES') }

1;
