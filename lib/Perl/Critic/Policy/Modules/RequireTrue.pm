package Perl::Critic::Policy::Modules::RequireTrue;
# ABSTRACT: don't be critical if we 'use true'
use 5.006001;
use strict;
use warnings;
use Readonly;
use Perl::Critic::Utils qw{ $EMPTY };
use base 'Perl::Critic::Policy::Modules::RequireEndWithOne';

Readonly::Scalar my $EXPL => q{Must end with a recognizable true value, or use NAP::policy};
Readonly::Scalar my $DESC => q{Module does not end with "1;" and does not use NAP::policy};

sub supported_parameters {
    return (
        {
            name            => 'equivalent_modules',
            description     =>
                q<The additional modules to treat as equivalent to "1;" at the end.>,
            default_string  => $EMPTY,
            behavior        => 'string list',
            list_always_present_values =>
                [ qw< NAP::policy true > ],
        },
    );
}

# copied from Perl::Critic::Policy::TestingAndDebugging::RequireUseStrict
sub _generate_is_use_true {
    my ($self) = @_;

    return sub {
        my (undef, $elem) = @_;

        return 0 if !$elem->isa('PPI::Statement::Include');
        return 0 if $elem->type() ne 'use';

        # We only want file-scoped pragmas
        my $parent = $elem->parent();
        return 0 if !$parent->isa('PPI::Document');

        if ( my $pragma = $elem->pragma() ) {
            return 1 if $self->{_equivalent_modules}{$pragma};
        }
        elsif ( my $module = $elem->module() ) {
            return 1 if $self->{_equivalent_modules}{$module};
        }
        return 0;
    };
}

sub violates {
    my ( $self, undef, $doc ) = @_;

    return if $doc->find_first($self->_generate_is_use_true);

    return $self->SUPER::violates(undef,$doc);
}

1;

=begin Pod::Coverage

violates

supported_parameters

=end Pod::Coverage
