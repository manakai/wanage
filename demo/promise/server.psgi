# -*- Perl -*-
use strict;
use warnings;
use File::Basename;
BEGIN { require ((dirname (__FILE__)) . '/../demo-lib.pl') }
use Wanage::HTTP;
use Warabe::App;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps/modules/*/lib');
use Promise;

require (file (__FILE__)->dir->file ('Web.pm')->stringify);

sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);
  my ($ok, $error);
  my $p = Promise->new (sub {
    ($ok, $error) = @_;
  })->then (sub {
    return Web->process ($app);
  })->catch (sub {
    $app->onexecuteerror->($_[0]);
    unless ($app->http->response_headers_sent) {
      $app->send_error (500);
    }
  })->catch (sub {
    warn $_[0];
  });
  return $http->send_response (onready => sub { $ok->() });
};

## License: Public Domain.
