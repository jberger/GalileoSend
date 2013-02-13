#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::UserAgent;
use Mojo::IOLoop;
use Fcntl 'SEEK_SET';

use Mojo::URL;
use Mojo::JSON 'j';

use File::Basename;
use Getopt::Long;

GetOptions(
  'chunksize=i' => \(my $chunksize = 250000),
);

my $url = shift;
$url = "//$url" unless $url =~ m!^(?:\w+:)?//!; # must be an absolute url
$url = Mojo::URL->new($url);
$url->scheme('ws');
$url = "$url";

my $ua = Mojo::UserAgent->new;
my $delay = Mojo::IOLoop->delay;

setup_ws($_) for @ARGV;

$delay->wait unless $delay->ioloop->is_running;

sub setup_ws {
  my $file = shift;
  unless ( -e $file ) {
    warn "$file cannot be accessed, aborting\n";
    return;
  }

  my $filedata = {
    name => (scalar fileparse $file),
    size => -s $file,
  };

  my $slice_start = 0;
  my $end = $filedata->{size};
  my $finished = 0;
  my $success = 0;  # set to true on completion
  my $error_messages = [];

  $delay->begin;

  $ua->websocket( $url => sub {
    my ($ua, $tx) = @_;

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
        mywarn( $status->{error} );
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
      my $fh;
      unless ( open $fh, '<', $file ) {
        warn "$file could not be opened, aborting\n";
        return;
      };

      my $temp;
      sysseek $fh, $slice_start, SEEK_SET;
      my $read = sysread $fh, $temp, ($status->{chunksize} || $chunksize);
      unless ( defined $read ) {
        warn "Error reading from $file\n";
        return;
      }

      if ( $read ) {
        $slice_start += $read;
        warn $slice_start / $end * 100 . "%\n";
      } else {
        $finished = 1;
      }

      $self->send({ binary => $temp });
    });

    $tx->on( finish => sub {
      if ( $success ) {
        print "$file sent successfully\n";

      } else {

        $error_messages->[0] = { error => 'Unknown upload error' }
          unless @$error_messages;

        require Data::Dumper;
        warn "$file upload failed with the following warnings:\n";
        warn Data::Dumper::Dumper($error_messages);
      }

      $delay->end;
    });

    $tx->send({ text => j( $filedata ) }) if $tx->is_websocket;
  });

}

sub mywarn { 
  my $message = shift;
  $message =~ s/(?<!\n)\z/\n/;  # add a newline if necessary
  warn $message;
}

