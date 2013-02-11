use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'GalileoSend';

get '/' => sub {
  my $self = shift;
  $self->render_text('Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

done_testing();
