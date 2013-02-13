package App::GalileoSend::File;

use Mojo::Base -base;

use Fcntl 'SEEK_SET';
use File::Basename;

has path   => sub { die "File objects must have a path\n" };
has handle => sub {
  open my $fh, '<', $_[0]->path or die "Cannot open file: $!";
  return $fh;
};
has max_chunksize => 250000;
has name => sub { scalar fileparse $_[0]->path };
has pos  => 0;
has size => sub { -s $_[0]->path };     #-# highlight fix

sub get_chunk {
  my $self = shift;
  my $max = shift || $self->max_chunksize;

  my $fh = $self->handle;
  my $start = $self->pos;    # current position

  sysseek $fh, $start, SEEK_SET;

  my $buffer;
  my $read = sysread $fh, $buffer, $max;
  unless ( defined $read ) {
    my $path = $self->path;
    die "Error reading from $path: $!\n";
  }

  $self->pos( $start + $read );

  return wantarray ? ( $buffer, $read ) : $buffer;
}

sub meta { +{
  name => $_[0]->name,
  size => $_[0]->size,
} }

1;

