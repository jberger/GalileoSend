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

  $app->helper( galileo_ready_signal => sub {
    my $self = shift;
    my $payload = { ready => \1 };
    $payload->{chunksize} = shift if @_;
    $self->send({ text => j($payload) });
  });

  $app->helper( galileo_error_signal => sub {
    my $self = shift;
    my $message = shift || 'Unspecified';
    my $payload = { 
      error => $message,
      fatal => $_[0] ? \1 : \0,
    };
    $self->send({ text => j($payload) });
  });

  $app->helper( galileo_close_signal => sub {
    my $self = shift;
    $self->send({ text => j({ close => \1 }) });
  });

  $app->helper( galileo_receive_file => sub {
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
    $self->on( file_start => sub { $_[0]->galileo_ready_signal } );

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
    $self->on( file_chunk => sub { $_[0]->galileo_ready_signal } );

    # save file
    $self->on( file_finish => sub {
      my ($ws, $file, $meta) = @_;

      my $size = $file->size;
      if ( defined $meta->{size} and $size != $meta->{size} ) {
        $ws->galileo_error_signal( "Expected: $meta->{size} bytes. Got: $size bytes.", 1 );
        return;
      }

      my $target = $meta->{name} || 'unknown';
      if ( -d $meta->{directory} ) {
        $target = File::Spec->catfile( $meta->{directory}, $target );
      }
      $file->move_to($target);
      my $message = sprintf q{Upload: '%s' - Saved to '%s'}, $meta->{name}, $target;
      $ws->app->log->debug( $message );
      $ws->galileo_close_signal;
    });

  });
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::GalileoSend - Websocket file uploads for Mojolicious (GalileoSend protocol)

=head1 SYNOPSIS

 # Example shown using Mojolicious::Lite
 plugin 'GalileoSend';

 websocket '/upload' => sub {
   $_[0]->galileo_receive_file({ directory => 'uploads' });
 };

=head1 DESCRIPTION

L<Mojolicious::Plugin::GalileoSend> is a L<Mojolicious> plugin which implements the L<GalileoSend|https://github.com/jberger/GalileoSend> protocol. This protocol is for sending files over websocket transport in a sane positive-confirmation way. This Mojolicious plugin is non-blocking and comes bundled with a javascript client implementation ready to use.

=head1 METHODS

L<Mojolicious::Plugin::GalileoSend> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 find_javascript_directory

 $plugin->find_javascript directory

This method finds and returns the directory containing the F<galileo_send.js> file. This might be in the development directory F<js/> before installation or in a directory managed by L<File::ShareDir> afterwards.

=head2 register

 $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

When called (usually by the C<plugin> helper as seen in the example) this sets up the provided helpers. Then necessary events and default handlers for those events are setup by the L</receive_file> helper.

=head1 HELPERS

=head2 galileo_receive_file

 $c->galileo_receive_file; # setup file uploads, to working directory
 $c->galileo_receive_file({ directory => 'uploads' }); # setup file uploads, to uploads directory
 $c->galileo_receive_file({ name => 'myname' }); # setup file uploads, override given file name

Connects handlers to the websocket C<text> and C<binary> events, and adds the new events below (see L</EVENTS>).

Optionally this helper can take up to two arguments. First a hash-reference of key-value pair of initial meta-data, this will override any provided from the data sent from the client. The client should send C<name> and C<size> keys, additionally the default handler will recognize a C<directory> key. 

The second argument (or only) is a hashref of 'unsafe' keys, that is keys which should not be merged from the client. If unspecified, the default handler considers the C<directory> key unsafe, this is so that the client cannot choose the directory where the server will save the file. The key-value pair that are scrubbed can be later accessed in the C<file_start> handler.

For simple use, this is the only action an app needs to take to prepare for file uploads.

=head2 galileo_ready_signal

 $c->galileo_ready_signal; # ready
 $c->galileo_ready_signal(1000); # ready for up to 1000 bytes

Sends the ready signal to the client, which requests the next file chunk. Optionally it takes a number representing the maximum number of bytes that the client should send.

=head2 galileo_error_signal

 $c->galileo_error_signal( 'The splines cannot be reticulated' ); # error
 $c->galileo_error_signal( 'No more frobs to baz', 1 ); # fatal error

Sends the error signal to the client. The first argument is a string, the message to send; the default is C<Unspecified> but you should do better than that. The second argument, if true, adds the C<fatal> flag to the error.

=head2 galileo_close_signal

 $c->galileo_close_signal;

Sends the close signal to the client. This should only be sent after receiving the finished signal; in which case this indicates success and tells the client to close the connection. Note that there is no 'failing close' signal, rather one should send a fatal error signal, even at this stage.

=head1 EVENTS

The L</galileo_receive_file> helper adds handlers to both the websocket C<text> and C<binary> events which should not be changed. Futher it causes the websocket to emit several new events.

Each event gets at least two parameters, the L<Mojo::Asset> object which gets the file stream, and a hash-reference of meta-data.

=head2 file_start

 $c->on( file_start => sub {
   my ($file, $meta, $unsafe) = @_;
   ...
 });

Emitted on connection and receipt of file meta-data. Any keys designated unsafe are filtered out and held in the C<unsafe> hashref, which is passed as the third parameter.

The default handler for this signal does nothing more than call L</galileo_ready_signal>.

=head2 file_chunk

 $c->on( file_chunk => sub {
    my ($file, $meta) = @_;
    ...
 });

Emitted on receipt of a chunk of the file. The L<Mojo::Asset> contained in the first argument will already reflect the added data.

Two handlers are attached to this signal by default, the first that logs debugging information, the second calls L</galileo_ready_signal> requesting the next chunk.

=head2 file_finish

 $c->on( file_finish => sub {
   my ($file, $meta) = @_;
   ...
 });

Emitted on receipt of the finish signal. The L<Mojo::Asset> contained in the first argument should now contain the entire file.

The default handler checks that the file size equals the expected file size (if known from the meta-data). It then saves the file the C<name> from the meta-data which should by now be specifed. It saves it to either the directory in the meta-data if known or to the current working directory.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/GalileoSend>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

