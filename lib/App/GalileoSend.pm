package App::GalileoSend;

use Mojo::Base -base;

use Mojo::UserAgent;
use Mojo::IOLoop;

use Mojo::URL;
use Mojo::JSON 'j';

use App::GalileoSend::File;

has [qw/max_chunksize url/];
has delay => sub { Mojo::IOLoop->delay };
has ua    => sub { Mojo::UserAgent->new };

sub send {
  my $self = shift;
  $self->start_tx( $_ ) for @_;
  $self->wait; 
}

sub start_tx {
  my ($self, $file) = @_;

  unless ( eval { $file->isa( 'App::GalileoSend::File' ) } ) {
    my $spec = { path => $file };
    if ( my $size = $self->max_chunksize ) {
      $spec->{max_chunksize} = $size;
    }
    $file = App::GalileoSend::File->new( $spec );
  }

  my $delay = $self->delay;
  $delay->begin;

  $self->ua->websocket( $self->ws_url => sub {
    my ($ua, $tx) = @_;

    die "Not a WebSocket connection\n" unless $tx->is_websocket;

    my $finished = 0;
    my $success = 0;  # set to true on completion
    my $error_messages = [];

    $tx->on( text => sub {
      my ($self, $text) = @_;
      my $status = j($text);

      # got close signal
      if ( $status->{close} ) {
        $success = 1 if $finished;
        $self->finish;
        return;
      }

      # server reports error
      if ( $status->{error} ) {
        _mywarn( $status->{error} );
        push @$error_messages, $status;
        $self->finish if $status->{fatal};
        return;
      }

      # anything else but ready signal is ignored
      return unless $status->{ready};

      #upload already successful, inform server
      if ( $finished ) {
        $self->send({ text => j({ finished => \1 }) });
        return;
      }

      # server is ready for next chunk
      my ($buffer, $read) = $file->get_chunk( $status->{chunksize} );

      if ( $read ) {
        warn $file->pos / $file->size * 100 . "%\n";
      } else {
        $finished = 1;
      }

      $self->send({ binary => $buffer });
    });

    $tx->on( finish => sub {
      if ( $success ) {
        print $file->name . " sent successfully\n";
      } else {
        $error_messages->[0] = { error => 'Unknown upload error' }
          unless @$error_messages;

        require Data::Dumper;
        warn $file->path . " upload failed with the following warnings:\n";
        warn Data::Dumper::Dumper($error_messages);
      }

      $delay->end;
    });

    $tx->send({ text => j( $file->meta ) });
  });
}

sub wait {
  my $self = shift;
  my $delay = $self->delay;
  $delay->wait unless $delay->ioloop->is_running;
}

sub ws_url {
  my $self = shift;
  my $url = shift || $self->url || die "Must have a URL\n";
  $url = "//$url" unless $url =~ m!^(?:\w+:)?//!; # must be an absolute url
  $url = Mojo::URL->new($url);
  $url->scheme('ws');
  return "$url";
}

### functions ###

sub _mywarn { 
  my $message = shift;
  $message =~ s/(?<!\n)\z/\n/;  # add a newline if necessary
  warn $message;
}

1;

