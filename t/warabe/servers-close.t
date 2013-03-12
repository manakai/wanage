use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::AnyEvent::plackup;
use Web::UserAgent::Functions qw(http_get);
use Test::X1;
use Test::More;

for my $impl (undef, qw(Starlet Twiggy)) {
  test {
    my $c = shift;
    my $server = Test::AnyEvent::plackup->new;
    $server->server ($impl);
    $server->set_app_code (q{
      use Warabe::App;
      use Wanage::HTTP;
      use AnyEvent;
      return sub {
        my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
        my $app = Warabe::App->new_from_http ($http);
        return $http->send_response (onready => sub {
          $app->execute (sub {
            my $timer; $timer = AE::timer 0, 1, sub {
              $app->send_error(201);
              undef $timer;
            };
            return $app->throw;
          });
        });
      };
    });

    my ($start_cv, $stop_cv) = $server->start_server;
    $start_cv->cb (sub {
      my $url = 'http://localhost:' . $server->port . '/';
      http_get url => $url, anyevent => 1, cb => sub {
        my $res = $_[1];
        test {
          is $res->code, 201;
        } $c;
        $server->stop_server;
      };
    });

    $stop_cv->cb (sub {
      done $c;
      undef $c;
    });
  } n => 1, name => ['use AnyEvent', $impl];

  test {
    my $c = shift;
    my $server = Test::AnyEvent::plackup->new;
    $server->server ($impl);
    $server->set_app_code (q{
      use Warabe::App;
      use Wanage::HTTP;
      return sub {
        my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
        my $app = Warabe::App->new_from_http ($http);
        return $http->send_response (onready => sub {
          $app->execute (sub {
            require AnyEvent;
            my $timer; $timer = AE::timer (0, 1, sub {
              $app->send_error (201);
              undef $timer;
            });
            return $app->throw;
          });
        });
      };
    });

    my ($start_cv, $stop_cv) = $server->start_server;
    $start_cv->cb (sub {
      my $url = 'http://localhost:' . $server->port . '/';
      http_get url => $url, anyevent => 1, cb => sub {
        my $res = $_[1];
        test {
          is $res->code, 201;
        } $c;
        $server->stop_server;
      };
    });

    $stop_cv->cb (sub {
      done $c;
      undef $c;
    });
  } n => 1, name => ['require AnyEvent', $impl];
} # $server

run_tests;
