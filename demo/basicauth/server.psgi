# -*- Perl -*-
use strict;
use warnings;
use File::Basename;
BEGIN { require ((dirname (__FILE__)) . '/../demo-lib.pl') }
use Wanage::HTTP;
use Warabe::App;
use Path::Class;

require (file (__FILE__)->dir->file ('BasicAuth.pm')->stringify);

sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  $app->execute (sub {
    BasicAuth->process ($app);
  });

  return $http->send_response;
};

## License: Public Domain.
