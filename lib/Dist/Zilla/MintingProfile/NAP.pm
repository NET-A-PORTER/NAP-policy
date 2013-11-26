package Dist::Zilla::MintingProfile::NAP;
use NAP::policy 'class';
with 'Dist::Zilla::Role::MintingProfile';
use File::ShareDir;
use Path::Class;

# ABSTRACT: minimal NAP minting profile

=head1 SYNOPSIS

  dzil new -P NAP My::New::Distribution

=head1 DESCRIPTION

Using this minting profile will generate a very minimal distribution
with our suggested C<dist.ini>, C<weaver.ini> and C<.gitignore>
files. It will also write a (mostly empty) main module for your
distribution.

There's plenty of improvements to be made, but this seems like a good
start.

=method C<profile_dir>

Returns the subdir with the same name as the profile name (C<-p>
option to C<dzil new>, defaults to C<default>) under the shared
distribution directory. Dies if such subdir does not exist.

=cut

# strongly inspired by the default MintingProfile

sub profile_dir {
  my ($self, $profile_name) = @_;

  $profile_name ||= 'default';

  if (!$ENV{NAP_OVERRIDE_PROFILE}) {
      my $profile_dir = dir(File::ShareDir::dist_dir('NAP-policy'))
          ->subdir('minting-profiles', $profile_name);

      return $profile_dir if -d $profile_dir;
  }
  else {
      return dir($ENV{NAP_OVERRIDE_PROFILE})->subdir('minting-profiles', $profile_name);
  }

  confess "Can't find profile $profile_name via $self";
}
