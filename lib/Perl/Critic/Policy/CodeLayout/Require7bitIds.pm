package Perl::Critic::Policy::CodeLayout::Require7bitIds;
# ABSTRACT: require 7-bit clean identifiers, even under "use utf8"
use 5.006001;
use strict;
use warnings;
use Readonly;
use Perl::Critic::Utils qw{ $EMPTY :severities };
use base 'Perl::Critic::Policy';
use feature 'unicode_strings';

Readonly::Scalar my $EXPL => q{Identifiers must use normal ASCII letters/digits};
Readonly::Scalar my $DESC => q{Identifier uses non-ASCII letter/digit};

sub applies_to { 'PPI::Token::Symbol', 'PPI::Token::Word' }
sub default_severity { $SEVERITY_HIGH }

sub violates {
    my ($self, $token, $doc) = @_;

    if ($token->content =~ m{\P{IsASCII}}) {
        return $self->violation($DESC,$EXPL,$token);
    }
    return;
}

1;
