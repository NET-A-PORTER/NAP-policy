package Dist::Zilla::Plugin::PkgVersionNoCritic;
BEGIN {
  $Dist::Zilla::Plugin::PkgVersionNoCritic::VERSION = '0.1';
}
# ABSTRACT: add a $VERSION to your packages, w/o Critic complaining
use Moose;
extends 'Dist::Zilla::Plugin::PkgVersion';

use PPI;
use MooseX::Types::Perl qw(LaxVersionStr);
use namespace::autoclean;

=head1 Overridden methods

=head2 C<munge_perl>

copied from L<Dist::Zilla::Plugin::PkgVersion>, but the inserted code has
C<## no critic (RequireUseStrict, RequireUseWarnings)> at the end of
each line.

=cut

sub munge_perl {
  my ($self, $file) = @_;

  my $version = $self->zilla->version;

  Carp::croak("invalid characters in version")
    unless LaxVersionStr->check($version);

  my $content = $file->content;

  my $document = PPI::Document->new(\$content)
    or Carp::croak( PPI::Document->errstr );

  # This is sort of stupid.  We want to see if we assign to $VERSION already.
  # I'm sure there's got to be a better way to do this, but what the heck --
  # this should work and isn't too slow for me. -- rjbs, 2009-11-29
  my $code_only = $document->clone;
  $code_only->prune("PPI::Token::$_") for qw(Comment Pod Quote Regexp);
  if ($code_only->serialize =~ /\$VERSION\s*=/sm) {
      $self->log([ 'skipping %s: assigns to $VERSION', $file->name ]);
      return;
  }

  return unless my $package_stmts = $document->find('PPI::Statement::Package');

  my %seen_pkg;

  for my $stmt (@$package_stmts) {
    my $package = $stmt->namespace;

    if ($seen_pkg{ $package }++) {
      $self->log([ 'skipping package re-declaration for %s', $package ]);
      next;
    }

    if ($stmt->content =~ /package\s*(?:#.*)?\n\s*\Q$package/) {
      $self->log([ 'skipping private package %s in %s', $package, $file->name ]);
      next;
    }

    # the \x20 hack is here so that when we scan *this* document we don't find
    # an assignment to version; it shouldn't be needed, but it's been annoying
    # enough in the past that I'm keeping it here until tests are better
    my $trial = $self->zilla->is_trial ? ' # TRIAL' : '';
    my $perl = <<"EOP";
BEGIN {  ## no critic (RequireUseStrict, RequireUseWarnings)
  \$$package\::VERSION\x20=\x20'$version';$trial ## no critic (RequireUseStrict, RequireUseWarnings)
}  ## no critic (RequireUseStrict, RequireUseWarnings)
EOP

    my $version_doc = PPI::Document->new(\$perl);
    my @children = $version_doc->schildren;

    $self->log_debug([
      'adding $VERSION assignment to %s in %s',
      $package,
      $file->name,
    ]);

    Carp::carp("error inserting version in " . $file->name)
      unless $stmt->insert_after($children[0]->clone)
      and    $stmt->insert_after( PPI::Token::Whitespace->new("\n") );
  }

  $file->content($document->serialize);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
