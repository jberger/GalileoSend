use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Cwd;

use File::Temp ();

use GalileoSend;
use GalileoSend::File;

my $orig = getcwd;
my $dir = File::Temp->newdir;

chdir $dir or die "Cannot chdir to temporary directory $dir";

my $sent = 'sent';
my $bytes = 1e6;

{
  open my $fh, '>', $sent or die "Cannot open file $sent";
  print $fh 'X' x $bytes;
}

is -s $sent, $bytes, "File '$sent' is correct size";

my $t = Test::Mojo->new('GalileoSend::Receiver');

{
  no warnings 'redefine';
  my $url = $t->app->url_for('/')->to_abs;
  *GalileoSend::ws_url = sub { $url };
}

my $ua = $t->ua;
my $sender = GalileoSend->new( ua => $ua, delay => $ua->ioloop->delay );

my $got = 'got';
my $file = GalileoSend::File->new( path => $sent, name => $got );

$sender->send( $file );

ok -e $got, "File $got was sent";
is -s $got, $bytes, "File '$got' is correct size"; 

chdir $orig or die "Cannot chdir back to $orig";
done_testing;

