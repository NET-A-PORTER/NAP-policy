package NAP::Exception::Role::StackTrace;
use NAP::policy 'role';
with 'StackTrace::Auto';

around _build_stack_trace_args => sub {
    my ($orig,$self) = @_;

    my $ret = $self->$orig();
    push @$ret, (
        no_refs => 1,
        respect_overload => 1,
        message => '',
        indent => 1,
    );

    return $ret;
};
