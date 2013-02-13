package App::GalileoSend::Receiver;

use Mojo::Base 'Mojolicious';

sub startup {
  my $self = shift;
  $self->plugin('GalileoSend');
  $self->routes->websocket( '/' => sub { $_[0]->galileo_receive_file } );
}

1;

