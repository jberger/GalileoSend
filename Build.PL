use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Mojolicious::Plugin::GalileoSend',
  dist_author => 'Joel Berger',
  license => 'perl',
  
  requires => {
    'Mojolicious' => '3.86',  # Mojo::Asset::File changes
    'File::ShareDir' => 0,
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },

  share_dir => 'js',

  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/GalileoSend",
      bugtracker => "http://github.com/jberger/GalileoSend/issues",
    },
  }
);

$builder->create_build_script;

