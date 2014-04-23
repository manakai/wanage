use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*//lib');
use Test::Wanage::Envs;
use Test::X1;
use Test::More;
use Wanage::HTTP;
use Warabe::App;

for my $method (qw(
  requires_same_origin
)) {
  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_no_origin';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      HTTP_ORIGIN => 'http://hoge.fuga',
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 200 OK
Content-Type: text/plain; charset=utf-8

ok};
    done $c;
  } n => 1, name => 'requires_same_origin_same_origin';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      HTTP_ORIGIN => 'https://hoge.fuga',
      HTTPS => 'on',
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 443,
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 200 OK
Content-Type: text/plain; charset=utf-8

ok};
    done $c;
  } n => 1, name => 'requires_same_origin_same_origin';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      HTTP_ORIGIN => 'http://hoge.fuga:801',
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 801,
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 200 OK
Content-Type: text/plain; charset=utf-8

ok};
    done $c;
  } n => 1, name => 'requires_same_origin_same_origin_port';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
      HTTP_ORIGIN => 'http://hoge.fuga.',
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_wrong_origin';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
      HTTP_ORIGIN => 'http://hoge.fuga:80',
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_wrong_origin';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
      HTTPS => 1,
      HTTP_ORIGIN => 'http://hoge.fuga:80',
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_wrong_scheme';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
      HTTP_ORIGIN => 'null',
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_null';

  test {
    my $c = shift;
    my $out = '';
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      SERVER_NAME => 'hoge.fuga',
      SERVER_PORT => 80,
      HTTP_ORIGIN => 'http://hoge.fuga,http://fuga.hoge',
    }, undef, $out;
    my $app = Warabe::App->new_from_http ($http);
    $app->execute (sub {
      $app->$method;
      $app->send_plain_text ('ok');
    });
    is $out, q{Status: 400 Bad origin
Content-Type: text/plain; charset=us-ascii

400 Bad origin};
    done $c;
  } n => 1, name => 'requires_same_origin_wrong_origins';
} # $method

run_tests;

$Warabe::App::DetectLeak = 1;

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
