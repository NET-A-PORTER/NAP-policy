package Dist::Zilla::Plugin::PkgDistNoCritic;
# ABSTRACT: add a $DIST to your packages, w/o Critic complaining
use Moose;
extends 'Dist::Zilla::Plugin::PkgDist';

=head1 Overridden methods

=head2 C<munge_perl>

copied from L<Dist::Zilla::Plugin::PkgDist>, but the inserted code has
C<## no critic (RequireUseStrict, RequireUseWarnings)> at the end of
each line.

=cut

sub munge_perl {
  my ($self, $file) = @_;

  my $dist_name = $self->zilla->name;

  my $content = $file->content;

  my $document = PPI::Document->new(\$content)
    or Carp::croak( PPI::Document->errstr );

  {
    # This is sort of stupid.  We want to see if we assign to $DIST already.
    # I'm sure there's got to be a better way to do this, but what the heck --
    # this should work and isn't too slow for me. -- rjbs, 2009-11-29
    my $code_only = $document->clone;
    $code_only->prune("PPI::Token::$_") for qw(Comment Pod Quote Regexp);
    if ($code_only->serialize =~ /\$DIST\s*=/sm) {
      $self->log([ 'skipping %s: assigns to $DIST', $file->name ]);
      return;
    }
  }

  return unless my $package_stmts = $document->find('PPI::Statement::Package');

  my %seen_pkg;

  for my $stmt (@$package_stmts) {
    my $package = $stmt->namespace;

    if ($seen_pkg{ $package }++) {
      $self->log([ 'skipping package re-declaration for %s', $package ]);
      next;
    }

    if ($stmt->content =~ /package\s*\n\s*\Q$package/) {
      $self->log([ 'skipping private package %s', $package ]);
      next;
    }

    # the \x20 hack is here so that when we scan *this* document we don't find
    # an assignment to version; it shouldn't be needed, but it's been annoying
    # enough in the past that I'm keeping it here until tests are better
    my $perl = <<"EOP";
BEGIN {  ## no critic (RequireUseStrict, RequireUseWarnings)
  \$$package\::DIST\x20=\x20'$dist_name';  ## no critic (RequireUseStrict, RequireUseWarnings)
}  ## no critic (RequireUseStrict, RequireUseWarnings)
EOP

    my $dist_doc = PPI::Document->new(\$perl);
    my @children = $dist_doc->schildren;

    $self->log_debug([
      'adding $DIST assignment to %s in %s',
      $package,
      $file->name,
    ]);

    Carp::carp('error inserting $DIST in ' . $file->name)
      unless $stmt->insert_after($children[0]->clone)
      and    $stmt->insert_after( PPI::Token::Whitespace->new("\n") );
  }

  $file->content($document->serialize);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
