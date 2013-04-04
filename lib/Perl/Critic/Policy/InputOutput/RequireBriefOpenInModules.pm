package Perl::Critic::Policy::InputOutput::RequireBriefOpenInModules;
# ABSTRACT: Close filehandles as soon as possible after opening them, but only in modules
use 5.006001;
use strict;
use warnings;
use Perl::Critic::Utils ':booleans';
use base 'Perl::Critic::Policy::InputOutput::RequireBriefOpen';

sub prepare_to_scan_document {
    my ($self,$document) = @_;

    return $document->is_module;
}

1;
