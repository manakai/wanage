use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;

use Wanage::HTTP;
use Test::Wanage::Envs;

test {
  my $c = shift;
  
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response;

  my $st = $http->response_timing ('foo');
  $st->add;
  
  $http->set_response_header ('X-Hoge' => 'ab cd');
  $http->set_response_header ('X-Hoge' => 'xy zz');
  $http->set_response_header ('X-ABC' => '111');
  $http->send_response_body_as_ref (\"abc");

  my $st2 = $http->response_timing (2);
  $st->add;
  
  is $out, "Status: 200 OK\nX-ABC: 111\nX-Hoge: xy zz\n\nabc";
  done $c;
} n => 1, name => 'not enabled';

test {
  my $c = shift;
  
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response;

  my $st0 = $http->response_timing (3);

  $http->response_timing_enabled (1);

  my $st = $http->response_timing ('foo');
  my $st4 = $http->response_timing ('bar');
  $st4->add;
  $st->add;
  $st0->add;
  
  $http->set_response_header ('X-Hoge' => 'ab cd');
  $http->set_response_header ('X-Hoge' => 'xy zz');
  $http->set_response_header ('X-ABC' => '111');
  $http->send_response_body_as_ref (\"abc");

  my $st2 = $http->response_timing (2);
  $st->add;
  
  like $out, qr{\AStatus: 200 OK\nX-ABC: 111\nX-Hoge: xy zz\nserver-timing: bar;dur=[0-9.]+\nserver-timing: foo;dur=[0-9.]+\n\nabc\z}, $out;
  done $c;
} n => 1, name => 'enabled';

test {
  my $c = shift;
  
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response;
  $http->response_timing_enabled (1);

  my $st = $http->response_timing ("\x00\x{4e00};", desc => "\x{6001}\x09\x5C'\x22");
  $st->add;
  
  $http->send_response_body_as_ref (\"abc");

  my $st2 = $http->response_timing (2);
  $st->add;
  
  like $out, qr{\AStatus: 200 OK\nserver-timing: %00%E4%B8%80%3B;dur=[0-9.]+;desc="\xE6\x80\x81%09\\\\'\\""\n\nabc\z}, $out;
  done $c;
} n => 1, name => 'chars';

test {
  my $c = shift;
  
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response;
  $http->response_timing_enabled (1);

  my $st = $http->response_timing ("\x00\x{4e00};-->--", desc => "-->\x{6001}\x09\x5C'\x22<!----!>");
  $st->send_html;
  
  $http->send_response_body_as_ref (\"abc");

  my $st2 = $http->response_timing (2);
  $st2->add;

  is $http->response_timing_enabled, 1;
  $http->response_timing_enabled (0);
  is $http->response_timing_enabled, 0;

  my $st3 = $http->response_timing (3);
  $st3->send_html;

  like $out, qr{\AStatus: 200 OK\n\n\n<!--\nserver-timing: %00%E4%B8%80%3B-%2D%3E-%2D;dur=[0-9.]+;desc="-%2D>\xE6\x80\x81%09\\\\'\\"<!-%2D-%2D!>"\n-->abc\z}, $out;
  done $c;
} n => 3, name => 'html';

run_tests;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
