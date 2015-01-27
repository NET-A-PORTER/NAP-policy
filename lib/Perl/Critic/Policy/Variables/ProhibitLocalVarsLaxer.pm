package Perl::Critic::Policy::Variables::ProhibitLocalVarsLaxer;
# ABSTRACT: like ProhibitLocalVars, but allow localising pieces of data structures
use strict;
use warnings;
use base 'Perl::Critic::Policy::Variables::ProhibitLocalVars';

sub violates {
    my ($self,$elem,@etc) = @_;

    return unless $elem->type eq 'local';
    my ($symbol) = $elem->symbols;
    return unless $symbol; # it does not even look like a local $somethinng
    my $next = $symbol->snext_sibling;
    return if $next->isa('PPI::Structure::Subscript');
    return if $next->isa('PPI::Token::Operator')
        and $next->content eq '->';
    return $self->SUPER::violates($elem,@etc);
}

1;
