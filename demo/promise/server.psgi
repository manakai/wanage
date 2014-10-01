# -*- Perl -*-
use strict;
use warnings;
use File::Basename;
BEGIN { require ((dirname (__FILE__)) . '/../demo-lib.pl') }
use Wanage::HTTP;
use Warabe::App;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps/modules/*/lib');

require (file (__FILE__)->dir->file ('Web.pm')->stringify);

sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);
  return $app->execute_by_promise (sub { return Web->process ($app) });
};

## License: Public Domain.
