package BasicAuth;
use strict;
use warnings;

sub process ($$) {
  my ($class, $app) = @_;

  if ($app->path_segments->length == 2) {
    $app->requires_basic_auth ({
      $app->path_segments->[0] => $app->path_segments->[1],
    });
    $app->send_plain_text ("OK");
  } else {
    $app->throw_redirect (q</user/pass>);
  }
} # process

1;

## License: Public Domain.
