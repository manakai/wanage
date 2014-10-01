package Web;
use strict;
use warnings;
use AnyEvent;
use Promise;
use Web::UserAgent::Functions qw(http_get);

sub process ($$) {
  my ($class, $app) = @_;
  my $path = $app->path_segments;
  if ($path->[0] eq '500') {
    die "died";
  } elsif ($path->[0] eq 'clock') {
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      my $clock = 0;
      $app->http->send_response_body_as_ref (\(" " x 1024));
      my $timer; $timer = AE::timer 0, 1, sub {
        $app->http->send_response_body_as_ref (\"$clock\n");
        $clock++;
        if ($clock > 3) {
          $app->http->close_response_body;
          $ok->();
          undef $timer;
        }
      };
    });
  } elsif ($path->[0] eq 'example') {
    return Promise->new (sub {
      my ($ok, $error) = @_;
      die "error1" if $app->bare_param ('error1');
      http_get
          url => q<http://www.example.com/>,
          anyevent => 1,
          cb => sub {
            my (undef, $res) = @_;
            if ($res->is_success and not $app->bare_param ('error3')) {
              $ok->($res->content);
            } else {
              $error->($res->code);
            }
          };
    })->then (sub {
      die "error2" if $app->bare_param ('error2');
      $app->send_plain_text ($_[0]);
    }, sub {
      die "error4" if $app->bare_param ('error4');
      $app->send_error (502, reason_phrase => "Remote server returns $_[0]");
    });
  } else {
    $app->send_plain_text ("OK");
  }
} # process

1;

## License: Public Domain.
