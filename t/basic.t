use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use File::Temp ();
use File::Spec;

use Mojo::JSON 'j';

plugin 'GalileoSend';

sub json  { return +{ text   => j(shift) } }
sub bytes { return +{ binary => shift    } }

my $dir = File::Temp->newdir;
my ($file, $meta, $unsafe);

websocket '/' => sub {
  my $self = shift;

  $self->receive_file({ directory => "$dir" });

  my $monitor = sub {
    (undef, $file, $meta, $unsafe) = @_; # unsafe only sent on file_start
  };

  $self->on( file_start  => $monitor );
  $self->on( file_chunk  => $monitor );
  $self->on( file_finish => $monitor );
};

my $t = Test::Mojo->new;

# test file_start

my $filename = 'myfile';
my $sent_meta = { name => $filename, size => 10, directory => 'unsafe' };
$t->websocket_ok('/')
  ->send_ok(json( $sent_meta ))
  ->message_ok
  ->json_message_is( '/' => { ready => 1 } );

isa_ok( $file, 'Mojo::Asset');

{
  local $meta->{directory} = $meta->{directory}; # protect for later use

  is( $unsafe->{directory}, delete $sent_meta->{directory}, 'unsafe keys scrubbed' );
  is( delete $meta->{directory}, "$dir", 'directory gets merged into meta' );

  is_deeply( $meta, $sent_meta, 'meta round-trip' );
}

# test file_chunk

$t->send_ok(bytes('x' x 10))
  ->message_ok
  ->json_message_is( '/' => { ready => 1 } );

is( $file->size, 10, 'got size');

# test file_finished

$t->send_ok(json({ finished => \1 }))
  ->finish_ok;

my $file_path = File::Spec->catfile( "$dir", $filename );
ok( -e $file_path, 'File created' );
is( -s $file_path, 10, 'File has correct size' );

done_testing();

