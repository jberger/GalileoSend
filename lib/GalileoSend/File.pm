package GalileoSend::File;

use Mojo::Base 'Mojo::Asset::File';

use File::Basename;

has cleanup => 0;
has max_chunksize => 250000;
has name => sub { scalar fileparse $_[0]->path };
has path => sub { die "GalileoSend::File objects must have a path\n" };
has pos  => 0;

sub get_next_chunk {
  my $self = shift;
  my $max = shift || $self->max_chunksize;

  my $start = $self->pos;
  my $buffer = $self->get_chunk( $start, $max );

  my $read = do { use bytes; length $buffer };

  $self->pos( $start + $read );

  return wantarray ? ( $buffer, $read ) : $buffer;
}

sub meta { +{
  name => $_[0]->name,
  size => $_[0]->size,
} }

1;

