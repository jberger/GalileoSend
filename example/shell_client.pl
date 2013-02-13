#!/usr/bin/env perl

use App::GalileoSend;
use Getopt::Long;

my $spec = {};
GetOptions(
  'chunksize=i' => \$spec->{max_chunksize},
);

$spec->{url} = shift;

my $sender = App::GalileoSend->new( $spec );
$sender->send( @ARGV );

