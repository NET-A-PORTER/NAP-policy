package NAP::Exception::Formatter;
use strict;
use warnings;
use base 'String::Errf';
use Scalar::Util ();

# ABSTRACT: formatter for exception messages

=head1 SYNOPSIS

  say NAP::Exception::Formatter->new->format(
       'foo: %{foo}s, bar: %{bar}d',
       { foo => 'argh', bar => 15 }
  );

prints:

  foo: argh, bar: 15

=head1 DESCRIPTION

This class inherits from L<String::Errf>. It requires exactly 2 values
for its C<format> method, the first being the format string, the
second being a hashref or an object.

Replacements in the format string are tried as methods of the object,
or as slot of the hashref (or of the
hashref-underlying-the-object). If the value thus obtained is an
object with a C<as_string> method, the method is called; otherwise,
the value is passed on untouched.

An undefined value will be printed as C<< <undef> >>, regardless of
the conversion specifier.

=begin Pod::Coverage

import
default_input_processor
default_string_replacer

=end Pod::Coverage

=cut

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

    return;
}

# what follows is equivalent to C<< around [qw(_format...)] =>
# $filter_undefs >>, but we don't have Moose here, so we do it the
# old-fashioned way

my $around = sub {
    my ($orig,$wrap) = @_;
    ## no critic (ProhibitNoStrict)
    no strict 'refs';
    my $orig_ref = __PACKAGE__->can($orig);
    *{$orig} = sub { $wrap->($orig_ref,@_) };
    return;
};

my $filter_undefs = sub {
    my ($orig,$self,$value,@rest) = @_;
    return '<undef>' unless defined $value;
    return $self->$orig($value,@rest);
};

$around->($_,$filter_undefs) for qw(_format_string _format_int _format_float _format_numbered _format_timestamp);

1;
