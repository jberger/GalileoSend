package Mojolicious::Plugin::GalileoSend;
use Mojo::Base 'Mojolicious::Plugin';

use File::Spec;
use Mojo::JSON 'j';
use Mojo::Asset::Memory;
use File::ShareDir qw/dist_dir/;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub find_javascript_directory {
  my ($vol, $path, undef) = File::Spec->splitpath( File::Spec->rel2abs( __FILE__ ) );
  my @path = File::Spec->splitdir( $path );
  splice @path, -4; # .. to below lib
  push @path, 'js';
  my $local_dir = File::Spec->catpath($vol, File::Spec->catdir(@path));
  
  if (-d $local_dir) {
    my $file = File::Spec->catfile( $local_dir, 'galileo_send.js' );
    return $local_dir if -e $file;
  }

  my $share_dir = dist_dir( 'Mojolicious-Plugin-GalileoSend' );
  if (-d $share_dir) {
    my $file = File::Spec->catfile( $share_dir, 'galileo_send.js' );
    return $share_dir if -e $file;
  }

  die "Could not find static files path ($local_dir, $share_dir)";
}

sub register {
  my ($self, $app) = @_;

  # find static folder
  push @{ $app->static->paths }, $self->find_javascript_directory;

  $app->helper( send_ready_signal => sub {
    my $self = shift;
    my $payload = { ready => \1 };
    $payload->{chunksize} = shift if @_;
    $self->send({ text => j($payload) });
  });

  $app->helper( send_error_signal => sub {
    my $self = shift;
    my $message = shift;
    my $payload = { 
      error => $message,
      fatal => $_[0] ? \1 : \0,
    };
    $self->send({ text => j($payload) });
  });

  $app->helper( send_close_signal => sub {
    my $self = shift;
    $self->send({ text => j({ close => \1 }) });
  });

  $app->helper( receive_file => sub {
    my $self = shift;

    # setup text/binary handlers
    # create file_start/file_chunk/file_finish events
    {
      my $unsafe_keys = eval { ref $_[-1] eq 'ARRAY' } ? pop : [qw/directory/];
      my $meta = shift || {};
      my $file = Mojo::Asset::Memory->new;

      $self->on( text => sub {
        my ($ws, $text) = @_;

        # receive file metadata
        my %got = %{ j($text) };

        # prevent client-side abuse
        my %unsafe;
        @unsafe{@$unsafe_keys} = delete @got{@$unsafe_keys};
        %$meta = (%got, %$meta);

        # finished
        if ( $got{finished} ) {
          $ws->tx->emit( file_finish => $file, $meta );
          return;
        }

        # inform the sender to send the file
        $ws->tx->emit( file_start => $file, $meta, \%unsafe );
      });

      $self->on( binary => sub {
        my ($ws, $bytes) = @_;

        $file->add_chunk( $bytes );
        $ws->tx->emit( file_chunk => $file, $meta );
      });
    }

    # connect default handlers for new file_* events

    # begin file receipt
    $self->on( file_start => sub { $_[0]->send_ready_signal } );

    # log progress
    $self->on( file_chunk => sub {
      my ($ws, $file, $meta) = @_;
      state $old_size = 0;
      my $new_size = $file->size;
      my $message = sprintf q{Upload: '%s' - %d | %d | %d}, $meta->{name}, ($new_size - $old_size), $new_size, $meta->{size};
      $ws->app->log->debug( $message );
      $old_size = $new_size;
    });

    # inform the sender to send the next chunk
    $self->on( file_chunk => sub { $_[0]->send_ready_signal } );

    # save file
    $self->on( file_finish => sub {
      my ($ws, $file, $meta) = @_;
      my $target = $meta->{name} || 'unknown';
      if ( -d $meta->{directory} ) {
        $target = File::Spec->catfile( $meta->{directory}, $target );
      }
      $file->move_to($target);
      my $message = sprintf q{Upload: '%s' - Saved to '%s'}, $meta->{name}, $target;
      $ws->app->log->debug( $message );
      $ws->send_close_signal;
    });

  });
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::GalileoSend - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('GalileoSend');

  # Mojolicious::Lite
  plugin 'GalileoSend';

=head1 DESCRIPTION

L<Mojolicious::Plugin::GalileoSend> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::GalileoSend> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
