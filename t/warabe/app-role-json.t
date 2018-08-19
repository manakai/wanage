package test::Warabe::App::Role::JSON;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Wanage::Envs;
use Web::Encoding;
use Wanage::HTTP;

{
  package test::Warabe::App::Role::JSON::App::JSON;
  use base qw(Warabe::App::Role::JSON Warabe::App);
}

our $APP_CLASS = 'test::Warabe::App::Role::JSON::App::JSON';

sub _version : Test(1) {
  ok $Warabe::App::Role::JSON::VERSION;
} # _version

sub _request_json : Test(16) {
  for (
    [undef, undef],
    ['' => undef],
    ['""' => ''],
    ['1244' => 1244],
    ['"acd \uAA0a"' => "acd \x{AA0A}"],
    ['{"abc":"\uFEAA"}' => {abc => "\x{FEAA}"}],
    ['abc "aaaa"' => undef],
    [(encode_web_utf8 qq<{"abc\x{AA91}" : ["\x{99}\x{8111}"]}>)
     => {"abc\x{AA91}" => ["\x99\x{8111}"]}],
  ) {
    my $in = $_->[0];
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      CONTENT_LENGTH => defined $in ? length $in : undef,
    }, $in;
    my $app = $APP_CLASS->new_from_http ($http);
    my $json = $app->request_json;
    eq_or_diff $json, $_->[1];
    is $app->request_json, $json;
  }
} # _request_json

sub _json_param : Test(11) {
  for (
    [undef, undef, undef, undef],
    ['json=1241', undef, undef, '1241'],
    ['json="abcd"', undef, undef, 'abcd'],
    ['json=1241&json=xyaa', undef, undef, '1241'],
    ['json={"aaa":"bbb"}', undef, undef, {aaa => 'bbb'}],
    ['json=[1241, 1333]', undef, undef, ['1241', '1333']],
    ['json=%21', undef, undef, undef],
    ['json={x', undef, undef, undef],
    ['json={"\\u4E00":"\\u5000"}', undef, undef, {"\x{4e00}" => "\x{5000}"}],
    ['json="abcd"', 'application/x-www-form-urlencoded', 'json=341', 'abcd'],
    [undef, 'application/x-www-form-urlencoded', 'json=341', '341'],
  ) {
    my $in = $_->[2];
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      QUERY_STRING => $_->[0],
      CONTENT_TYPE => $_->[1],
      CONTENT_LENGTH => length $in,
    }, $in;
    my $app = $APP_CLASS->new_from_http ($http);
    my $json = $app->json_param ('json');
    eq_or_diff $json, $_->[3];
  }
}

sub _send_json : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_json ({"\x{4000}ab" => [123, "xyxz"]});
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json; charset=utf-8

{"\xe4\x80\x80ab":[123,"xyxz"]}};
} # _send_json

sub _send_json_undef : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_json (undef);
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json; charset=utf-8

null};
} # _send_json_undef

sub _send_json_scalar : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_json ("abcd\x{4000}");
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json; charset=utf-8

"abcd\xe4\x80\x80"};
} # _set_response_json_scalar

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
