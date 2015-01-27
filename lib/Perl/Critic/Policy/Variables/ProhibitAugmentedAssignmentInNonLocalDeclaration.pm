package Perl::Critic::Policy::Variables::ProhibitAugmentedAssignmentInNonLocalDeclaration;
# ABSTRACT: Do not write C< my $foo .= 'bar'; >
use strict;
use warnings;
use Readonly;
use Perl::Critic::Utils qw{ $TRUE };
use base 'Perl::Critic::Policy::Variables::ProhibitAugmentedAssignmentInDeclaration';

sub violates {
    my ($self, $elem, @etc) = @_;

    my ($declarator) = $elem->schildren;
    return if $declarator->isa('PPI::Token::Word')
        and $declarator->content() eq 'local';
    return $self->SUPER::violates($elem,@etc);
}

1;
