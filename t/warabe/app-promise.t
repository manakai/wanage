use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use File::Temp qw(tempfile);
use Test::AnyEvent::plackup;
use Web::UserAgent::Functions qw(http_get);
use Test::X1;
use Test::More;
use Promise;

sub http (&$) {
  my ($code, $url) = @_;
  return Promise->new (sub {
    my $ok = $_[0];
    http_get url => $url, anyevent => 1, cb => sub {
      $code->($_[1]);
      $ok->();
    };
  });
} # http

for my $impl (undef, qw(Starlet Twiggy)) {
  test {
    my $c = shift;
    my ($fh, $temp_file_name) = tempfile;

    my $server = Test::AnyEvent::plackup->new;
    $server->server ($impl);
    $server->perl_inc (\@INC);
    $server->set_env (TEMP_FILE_NAME => $temp_file_name);
    $server->set_app_code (q{
      use Warabe::App;
      use Wanage::HTTP;
      use Promise;
      use AnyEvent;
      use Web::UserAgent::Functions qw(http_get);
      return sub {
        my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
        my $app = Warabe::App->new_from_http ($http);
        return $app->execute_by_promise (sub {
          my $path = $app->path_segments;
          if ($path->[0] eq '500') {
            die "died";
          } elsif ($path->[0] eq 'clock') {
            return Promise->new (sub {
              my ($ok, $ng) = @_;
              my $clock = 0;
              my $timer; $timer = AE::timer 0, 0.1, sub {
                $app->http->send_response_body_as_ref (\"$clock\n");
                $clock++;
                if ($clock > 3) {
                  $app->http->close_response_body;
                  $ok->();
                  undef $timer;
                }
              };
            });
          } else {
            $app->send_plain_text ("OK");
          }
        });
      };
    });

    my ($start_cv, $stop_cv) = $server->start_server;
    return Promise->from_cv ($start_cv)->then (sub {
      my $url = 'http://localhost:' . $server->port;
      return Promise->all ([
        (http {
          my $res = $_[0];
          test {
            is $res->code, 200;
          } $c;
        } "$url/"),
        (http {
          my $res = $_[0];
          test {
            is $res->code, 500;
          } $c;
        } "$url/500"),
        (http {
          my $res = $_[0];
          test {
            is $res->content, join '', map { "$_\n" } 0..3;
          } $c;
        } "$url/clock"),
      ]);
    })->then (sub {
      $server->stop_server;
      return Promise->from_cv ($stop_cv);
    })->then (sub {
      test {
        done $c;
        undef $c;
      } $c;
    });
  } n => 3, name => [$impl];
} # $server

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
