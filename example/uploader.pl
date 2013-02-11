#!/usr/bin/env perl

use Mojolicious::Lite;
use File::Spec;

plugin 'GalileoSend';

any '/' => 'index';

websocket '/upload' => sub {
  my $self = shift;
  my $dir = $self->app->home->rel_dir('upload');
  mkdir $dir unless -d $dir;
  $self->receive_file({directory => $dir});
};

app->start;

__DATA__

@@ index.html.ep

<!DOCTYPE html>
<html>
  <head>
    <title>Testing</title>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.0/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.0/js/bootstrap.min.js"></script>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js"></script>
    %= javascript 'galileo_send.js'
    %= javascript begin
      function sendfile () {
        //var file = document.getElementById('file').files[0];
        var update = function(ratio) {
          var percent = Math.ceil( 100 * ratio );
          $('#progress .bar').css('width', percent + '%');
        };
        var success = function() {
          $('#progress').removeClass('progress-striped active');
          $('#progress .bar').addClass('bar-success');
        };
        var failure = function (messages) {
          $('#progress').removeClass('progress-striped active');
          $('#progress .bar').addClass('bar-danger');
          console.log(messages);
        };
        GalileoSend({
          url: '<%= url_for('upload')->to_abs %>',
          file: $('#file').get(0).files[0],
          onchunk: update,
          onsuccess: success,
          onfailure: failure
        });

      }
    % end
  </head>
  <body>
    <div class="container">
      <input id="file" type="file">
      <button onclick="sendfile()">Send</button>
      <div id="progress" class="progress progress-striped active">
        <div class="bar" style="width: 0%;"></div>
      </div>
    </div>
  </body>
</html>
