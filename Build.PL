use strict;
use warnings;

use 5.10.1;
use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Mojolicious::Plugin::GalileoSend',
  dist_author => 'Joel Berger',
  license => 'perl',
  
  requires => {
    'perl' => '5.10.1',
    'Mojolicious' => '3.83',  # Getopt::Long fix
    'File::ShareDir' => 0,
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },

  share_dir => 'js',

  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/Mojolicious-Plugin-GalileoSend",
      bugtracker => "http://github.com/jberger/Mojolicious-Plugin-GalileoSend/issues",
    },
  }
);

$builder->create_build_script;

