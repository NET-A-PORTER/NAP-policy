package NAP::Logging::Layout::PatternLayout::Multiline;
use NAP::policy 'tt';
use Log::Log4perl (); # this helps avoid load-order problems inside log4perl
use parent 'Log::Log4perl::Layout::PatternLayout';
use mro;

# ABSTRACT: multi-line layout, with custom formats for different lines

=head1 SYNOPSIS

 log4perl.appender.test.layout = NAP::Logging::Layout::PatternLayout::Multiline
 log4perl.appender.test.layout.ConversionPattern = UNUSED
 log4perl.appender.test.layout.ConversionPattern.FirstLine = +%m%n
 log4perl.appender.test.layout.ConversionPattern.ContLines = |%m%n
 log4perl.appender.test.layout.ConversionPattern.LastLine  = \%m%n

=head1 DESCRIPTION

This is just like L<Log::Log4perl::Layout::PatternLayout::Multiline>,
but it also allows you to specify different patterns for the first,
last, and other lines of a multi-line message.

=head2 Pattern selection

The first (or only) line of a message is formatted by
C<ConversionPattern.FirstLine>, or by C<ConversionPattern> if
C<FirstLine> is not set.

Subsequent lines, excluding the last one, are formatted by
C<ConversionPattern.ContLines>, or by C<ConversionPattern> if
C<ContLines> is not set.

The last line is formatted by C<ConversionPattern.LastLine>, or by
C<ConversionPattern.ContLines> if C<LastLine> is not set, or by
C<ConversionPattern> if neither C<LastLine> nor C<ContLines> is set.

=cut

# PatterLayout uses these attributes to store pre-computed information
# for the pattern; we need to keep multiple versions of each

my @format_fields = qw(printformat stack info_needed message_chompable);

# clear the "current" pattern attributes
sub _clear_format {
    my ($self) = @_;

    $self->{format} = undef;
    $self->{info_needed} = {};
    $self->{stack} = [];

    return;
}

# save "current" pattern into specified pattern
sub _save_format_to {
    my ($self,$sub_spec) = @_;

    for my $f (@format_fields) {
        $self->{"${sub_spec}_${f}"}=$self->{$f};
    }
    return;
}

# load specified pattern into "current" pattern
# it takes a list of patterns to load, loads the first one that
# exists, or the default one if none exist
sub _load_format_from {
    my ($self,@sub_specs) = @_;

    for my $sub_spec (@sub_specs,'default') {
        if (defined $self->{"${sub_spec}_$format_fields[0]"}) {
            for my $f (@format_fields) {
                $self->{$f}=$self->{"${sub_spec}_${f}"};
            }
            return;
        }
    }
    return;
}

sub new {
    my $class = shift;
    my $self = $class->next::method(@_);
    my $options = ref $_[0] eq "HASH" ? $_[0] : {};

    # the inherited constructor has compiled the default pattern
    $self->_save_format_to('default');

    for my $sub_spec (qw(FirstLine ContLines LastLine)) {
        if (exists $options->{ConversionPattern}{$sub_spec}{value}) {
            my $layout_string = $options->{ConversionPattern}{$sub_spec}{value};
            # non-portable line breaks, copied from PatternLayout
            $layout_string =~ s/\\n/\n/g;
            $layout_string =~ s/\\r/\r/g;

            # clear current pattern, compile it, save it
            $self->_clear_format;
            $self->define($layout_string);
            $self->_save_format_to($sub_spec);
        }
    }

    return $self;
}

sub render {
    my($self, $message, $category, $priority, $caller_level) = @_;

    my @messages = split /\r?\n/, $message;

    $caller_level = 0 unless defined $caller_level;

    my $result = '';

    while (my ($idx,$msg) = each @messages) {
        # for each line, load the appropriate format (or the default one)
        if ($idx == 0) {
            $self->_load_format_from('FirstLine');
        }
        elsif ($idx == $#messages) {
            $self->_load_format_from('LastLine','ContLines');
        }
        else {
            $self->_load_format_from('ContLines');
        }
        # actually format the line
        $result .= $self->next::method(
            $msg, $category, $priority, $caller_level + 1
        );
    }
    return $result;
}

=begin Pod::Coverage

new
render

=end Pod::Coverage
