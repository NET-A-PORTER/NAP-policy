package Dist::Zilla::Plugin::TemplateFile;
use Moose;
use Path::Tiny;
use Moose::Autobox;
use namespace::autoclean;
use Dist::Zilla::File::InMemory;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::TextTemplate',
);
# ABSTRACT: build a custom file from a template

has template => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has filename => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has name_is_template => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

sub gather_files {
    my ($self, $arg) = @_;

    my $file = Dist::Zilla::File::InMemory->new({
        name    => $self->_filename,
        content => $self->_content,
    });

    $self->add_file($file);
    return;
}

sub _content {
    my $self = shift;

    my $template = path($self->template)->slurp_utf8;

    return $self->fill_in_string(
        $template,
        {
            dist   => \($self->zilla),
            plugin => \($self),
        },
    );
}

sub _filename {
    my $self = shift;

    my $filename = $self->filename;

    if ($self->name_is_template) {
        $filename = $self->fill_in_string(
            $filename,
            {
                dist   => \($self->zilla),
                plugin => \($self),
            },
        );
    }

    return $filename;
}
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

In your dist.ini:

  [TemplateFile]
  template=some_file.txt
  filename=some_other_file.txt

or:

  [TemplateFile]
  template=some_file.txt
  filename={{ $dist->name }}.txt
  name_is_template=1

=head1 DESCRIPTION

Use this in minting profiles, to generate a file with a templated name
from a source template.

=head1 SEE ALSO

L<Dist:Zilla::Plugin::TemplateModule>,
L<Dist:Zilla::Plugin::GatherDir::Template>

=for Pod::Coverage gather_files
