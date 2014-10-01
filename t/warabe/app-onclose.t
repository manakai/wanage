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

for my $impl (undef, qw(Starlet Twiggy)) {
  for my $app_code (
    q{
      return $http->send_response (onready => sub {
        $app->execute (sub {
          $app->send_error (200);
          return $app->throw;
        });
      });
    },
    q{
      $app->execute (sub {
        $app->send_error (200);
        return $app->throw;
      });
      return $http->send_response;
    },
  ) {
    test {
      my $c = shift;
      my ($fh, $temp_file_name) = tempfile;

      my $server = Test::AnyEvent::plackup->new;
      $server->server ($impl);
      $server->set_env (TEMP_FILE_NAME => $temp_file_name);
      $server->set_app_code (sprintf q{
        use Warabe::App;
        use Wanage::HTTP;
        my $app_destroy = Warabe::App->can ('DESTROY');
        *Warabe::App::DESTROY = sub ($) {
          open my $temp_file, '>>', $ENV{TEMP_FILE_NAME} or die $!;
          print $temp_file "destroy";
          close $temp_file;
          goto &$app_destroy;
        };
        return sub {
          my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
          my $app = Warabe::App->new_from_http ($http);
          $app->onclose (sub {
            open my $temp_file, '>>', $ENV{TEMP_FILE_NAME} or die $!;
            print $temp_file "onclose";
            close $temp_file;
          });
          %s
        };
      }, $app_code);

      my ($start_cv, $stop_cv) = $server->start_server;
      $start_cv->cb (sub {
        my $url = 'http://localhost:' . $server->port . '/';
        http_get url => $url, anyevent => 1, cb => sub {
          my $res = $_[1];
          test {
            is $res->code, 200;
            $server->stop_server;
          } $c;
        };
      });

      $stop_cv->cb (sub {
        test {
          my $result = scalar file ($temp_file_name)->slurp;
          if ($result eq 'onclosedestroydestroy') {
            ## DESTROY might be invoked twice......
            is $result, 'onclosedestroydestroy';
          } else {
            is $result, 'onclosedestroy';
          }
          done $c;
          undef $c;
        } $c;
      });
    } n => 2, name => [$impl];
  } # $app_code
} # $server

run_tests;
