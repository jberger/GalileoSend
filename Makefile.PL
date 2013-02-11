use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::GalileoSend',
  VERSION_FROM => 'lib/Mojolicious/Plugin/GalileoSend.pm',
  AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '3.84'},
  test         => {TESTS => 't/*.t'}
);
