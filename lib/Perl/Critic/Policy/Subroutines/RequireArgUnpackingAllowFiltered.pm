package Perl::Critic::Policy::Subroutines::RequireArgUnpackingAllowFiltered;
# ABSTRACT: don't be critical if unpack with validated_* and similar
use strict;
use warnings;
use Readonly;
use Perl::Critic::Utils qw{ $TRUE };
use parent 'Perl::Critic::Policy::Subroutines::RequireArgUnpacking';
use Safe::Isa;

sub supported_parameters {
    return (
        Perl::Critic::Policy::Subroutines::RequireArgUnpacking::supported_parameters,
        {
            name => 'allow_filters',
            description =>
                q{Always unpack `@_' first, possibly via a filtering / validating function (you can shift $self first)},
            behavior => 'string list',
            list_always_present_values => [ qw< validate validate_pos validate_with validated_hash validated_list pos_validated_list > ],
        }
    );
}

sub violates {
    my ($self, $elem, @etc) = @_;

    my $block = $elem->block;
    return if not $block;
    my $block_class = ref($block);

    # WTH is going on here? well...
    #
    # the inherited policy is not very easily subclassable, so I'm
    # cheating. It requires an assignment from @_ to a list to be the
    # first statement, but we want to allow a "my $self=shift" to come
    # before that.

    # first of all, let's check if the $self=shift is there
    my $skip_self_shift_line=0;
    my ($first,@ret) = $block->schildren;
    if ($first
            && $first->isa('PPI::Statement::Variable')
            && $first->type eq 'my') {
        # yep, the first statement is a 'my'
        my @variables = $first->variables;
        if (@variables == 1 && $variables[0] eq '$self') {
            # and it declares a single variable called $self
            my $op = $first->find_first('PPI::Token::Operator');
            if ($op && $op->content eq '=') {
                # and it has an operator and it's a '='
                my $call = $op->snext_sibling;
                if ($call && $call->isa('PPI::Token::Word')
                        && $call->content eq 'shift') {
                    # and the next token is 'shift'
                    #
                    # we have found the line we wanted, let's remember
                    # to skip it
                    $skip_self_shift_line = 1;
                }
            }
        }
    }

    # now, we have to lie to the inherited policy!
    my $schildren = $block_class->can('schildren');
    no warnings 'redefine';no strict 'refs'; ## no critic(ProhibitNoStrict)
    # yes, I'm monkey-patching PPI
    local *{"${block_class}::schildren"} = sub {
        my ($self) = @_;
        # are we being called on the sub body? should we skip the
        # self=shift?
        if ($self == $block && $skip_self_shift_line) {
            # yes, return the rest of the body
            return @ret;
        }
        else {
            # no, return everything
            return $self->$schildren();
        }
    };

    # and finally we can delegate to the superclass
    return $self->SUPER::violates($elem,@etc);
}

sub _is_unpack {
    my ($self, $magic) = @_;

    return $TRUE if $self->SUPER::_is_unpack($magic);

    # this logic is very simple-minded; for example, it does not check
    # that we're assigning the result of the function call, and will
    # fail if we don't put parentheses in that call...

    my $expr = $magic->parent;
    return unless $expr->$_isa('PPI::Statement::Expression');
    my $list = $expr->parent;
    return unless $list->$_isa('PPI::Structure::List');
    my $func_name = $list->sprevious_sibling;
    return unless $func_name->$_isa('PPI::Token::Word');
    return $self->{_allow_filters}{$func_name};
}

1;

=for Pod::Coverage
supported_parameters

=cut
