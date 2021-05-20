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

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_redirect ("https://foo.bar/test 1");
  });
  is $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: https://foo.bar/test%201

<!DOCTYPE HTML><meta name=robots content="NOINDEX,NOARCHIVE"><meta name=referrer content=origin-when-cross-origin><title>Moved</title><a href="https://foo.bar/test%201">Next</a>};
  done $c;
} n => 1, name => '302';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_redirect ("https://foo.bar/test 1", refresh => 1);
  });
  is $out, q{Status: 200 OK
Content-Type: text/html; charset=utf-8

<!DOCTYPE HTML><meta name=robots content="NOINDEX,NOARCHIVE"><meta name=referrer content=origin-when-cross-origin><meta http-equiv=Refresh content="0;url=https://foo.bar/test%201"><title>Moved</title><a href="https://foo.bar/test%201">Next</a>};
  done $c;
} n => 1, name => 'refresh';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_redirect ("https://foo.bar/test 1", refresh => 1, status => 201);
  });
  is $out, q{Status: 201 Created
Content-Type: text/html; charset=utf-8

<!DOCTYPE HTML><meta name=robots content="NOINDEX,NOARCHIVE"><meta name=referrer content=origin-when-cross-origin><meta http-equiv=Refresh content="0;url=https://foo.bar/test%201"><title>Moved</title><a href="https://foo.bar/test%201">Next</a>};
  done $c;
} n => 1, name => 'refresh with status';

run_tests;

$Warabe::App::DetectLeak = 1;

=head1 LICENSE

Copyright 2012-2021 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
