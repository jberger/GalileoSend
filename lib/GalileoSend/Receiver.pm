package GalileoSend::Receiver;

use Mojo::Base 'Mojolicious';

use Cwd;

sub startup {
  my $self = shift;
  $self->plugin('GalileoSend');

  my $commands = $self->commands;
  $commands->namespaces([qw/GalileoSend::Receiver::Command/]);
  $commands->message(<<"EOF");
usage: $0 COMMAND [OPTIONS]

$0 is a very simple implementation of the GalileoSend protocol. This app
starts a server waiting to receive files via websockets. Received files 
are stored in the current working directory.
 
These commands are currently available:
EOF

  $commands->hint(<<"EOF");
 
These options are available for all commands:
    -h, --help          Get more information on a specific command.
    -m, --mode <name>   Run mode of your application, defaults to the value
                        of MOJO_MODE or "development".
 
See '$0 help COMMAND' for more information on a specific command.
EOF

  $self->routes->websocket( '/' => sub { $_[0]->galileo_receive_file } );
}

1;

