#!/usr/bin/env perl


#########################
#
# Not yet functioning !!!
#
#########################

use Mojo::Base -strict;

use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON 'j';

use File::Basename;
use Getopt::Long;

local $| = 1;

GetOptions(
  'chunksize=s' => \(my $chunksize = 250000),
);

my $url = shift;
$url = "//$url" unless $url =~ m!^(?:\w+:)?//!; # must be an absolute url
$url = Mojo::URL->new($url);
$url->scheme('ws');

sub mywarn { 
  my $message = shift;
  $message =~ s/(?<!\n)\z/\n/;  # add a newline if necessary
  warn $message;
}

sub setup_ws (_) {
  my $file = shift;
  unless ( -e $file ) {
    warn "$file cannot be accessed, aborting\n";
    return;
  }

  my $filedata = {
    name => scalar fileparse $file,
  };
  $filedata->{size} = -s $file;

  my $fh;
  unless ( open $fh, '<', $file ) {
    warn "$file could not be opened, aborting\n";
    return;
  };

  my $chunksize = $chunksize;
  my $slice_start = 0;
  my $end = $filedata->{size};
  my $finished = 0;
  my $success = 0;  # set to true on completion
  my $error_messages = [];

  my $ua = Mojo::UserAgent->new;

  $ua->websocket($url, sub {
    my ($self, $tx) = @_;

    $tx->on( text => sub {
      my ($self, $text) = @_;
      my $status = j($text);

      use DDP;
      p $status;

      # got close signal
      if ( $status->{close} ) {
        if ( $finished ) {
          $success = 1;
        }
        $self->client_close;
        return;
      }

      # server reports error
      if ( $status->{error} ) {
        mywarn $status->{error};
        push @$error_messages, $status;
        if ( $status->{fatal} ) {
          $self->client_close;
        }
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
      my $length = $status->{chunksize} || $chunksize;
      my $remaining = $end - $slice_start;
      $length = $remaining if $length > $remaining;

      my $temp;
      my $read = read $fh, $temp, $slice_start, $length;
      unless ( defined $read ) {
        warn "Error reading from $file\n";
        return;
      }

      $self->send({ binary => $temp });

      if ( $read ) {
        $slice_start += $read;
        warn $slice_start / $end * 100 . "%\n";
      } else {
        $finished = 1 unless $read;  # read returns 0 on EOF
        warn "100%\n";
      }
    });

    $tx->on( finish => sub {
      if ( $success ) {
        print "$file sent successfully\n";
        return;
      }

      unless ( @$error_messages ) {
        $error_messages->[0] = { error => 'Unknown upload error' };
      }

      require Data::Dumper;
      warn "$file upload failed with the following warnings:\n";
      warn Data::Dumper::Dumper($error_messages); 
    });

    $tx->send({ text => j( $filedata ) });
  });

  return $ua;
}

my @agents = map { setup_ws } @ARGV;

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

