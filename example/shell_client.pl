#!/usr/bin/env perl

if ( @ARGV ) {
  use App::GalileoSend;
  use Getopt::Long;

  my $spec = {};
  GetOptions(
    'chunksize=i' => \$spec->{max_chunksize},
  );

  $spec->{url} = shift;

  my $sender = App::GalileoSend->new( $spec );
  $sender->send( @ARGV );
  exit;
}

use Mojolicious::Lite;

plugin 'GalileoSend';

websocket( '/' => sub { $_[0]->galileo_receive_file } );

app->start;

