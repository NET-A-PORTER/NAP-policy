package NAP::Exception::Formatter;
use strict;
use warnings;
use base 'String::Errf';
use Scalar::Util ();

# we don't export anything, clobber the inherited method from
# Sub::Exporter
sub import {}

sub default_input_processor { 'require_single_input' }
sub default_string_replacer { '_nap_mixed_replacer' }

sub _nap_mixed_replacer {
    my ($self, $hunks, $input) = @_;

    for my $hunk (grep { ref } @$hunks) {

        my $slot = $hunk->{argument};
        if (Scalar::Util::blessed($input) && $input->can($slot)) {
            my $v = $input->$slot();
            if (Scalar::Util::blessed($v) && $v->can('as_string')) {
                $v = $v->as_string();
            }
            $hunk->{replacement} = $v;
        }
        else {
            $hunk->{replacement} = $input->{ $slot };
        }
        $hunk->{args}        = [ $hunk->{extra} ? split /;/, $hunk->{extra} : () ];
    }
}

# what follows is equivalent to C<< around [qw(_format...)] =>
# $filter_undefs >>, but we don't have Moose here, so we do it the
# old-fashioned way

my $around = sub {
    my ($orig,$wrap) = @_;
    ## no critic ProhibitNoStrict
    no strict 'refs';
    my $orig_ref = __PACKAGE__->can($orig);
    *{$orig} = sub { $wrap->($orig_ref,@_) };
};

my $filter_undefs = sub {
    my ($orig,$self,$value,@rest) = @_;
    return '<undef>' unless defined $value;
    return $self->$orig($value,@rest);
};

$around->($_,$filter_undefs) for qw(_format_string _format_int _format_float _format_numbered _format_timestamp);

1;
