package Perl::Critic::Policy::Modules::ProhibitExcessMainComplexityScriptAware;
# ABSTRACT: like ProhibitExcessMainComplexity, but disabled from anywhere
use strict;
use warnings;
use parent 'Perl::Critic::Policy::Modules::ProhibitExcessMainComplexity';

sub violates {
    my ( $self, $doc_elem, $full_doc ) = @_;

    my $fail = $self->SUPER::violates($doc_elem,$full_doc);
    if ($fail) {
        my $class = ref($self);
        for my $annotation ($full_doc->annotations) {
            # self-disable if we have an annotation that's not on the
            # first line
            # if we returned even for 1st line annotations,
            # ProhibitUselessNoCritic would always fail on the
            # annotation
            return if $annotation->disables_policy($class)
                and not $annotation->disables_line(1);
        }
        return $fail;
    }
    return;
}

1;
__END__

=head1 DESCRIPTION

To disable C<ProhibitExcessMainComplexity> you need a C<## no
critic(ProhibitExcessMainComplexity)> on the first line. But if you're
in a script, that first line is the shebang, and you don't want to
mess with that.

This policy disables itself if that C<## no critic> appears anywhere
in the file. You usually want to write it as:

  ## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

to silence the I<other> policy, which would complain because that line
does not I<technically> disable this policy. Just copy that line.
