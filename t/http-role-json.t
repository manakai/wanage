package test::Wanage::HTTP::Role::JSON;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Wanage::Envs;
use Wanage::HTTP::Full;
use Encode;

sub _version : Test(1) {
  ok $Wanage::HTTP::Role::JSON::VERSION;
} # _version

sub _request_json : Test(14) {
  for (
    [undef, undef],
    ['' => undef],
    ['1244' => 1244],
    ['"acd \uAA0a"' => "acd \x{AA0A}"],
    ['{"abc":"\uFEAA"}' => {abc => "\x{FEAA}"}],
    ['abc "aaaa"' => undef],
    [(encode 'utf-8', qq<{"abc\x{AA91}" : ["\x{99}\x{8111}"]}>)
     => {"abc\x{AA91}" => ["\x99\x{8111}"]}],
  ) {
    my $in = $_->[0];
    my $http = with_cgi_env { Wanage::HTTP::Full->new_cgi } {
      CONTENT_LENGTH => defined $in ? length $in : undef,
    }, $in;
    my $json = $http->request_json;
    eq_or_diff $json, $_->[1];
    is $http->request_json, $json;
  }
} # _request_json

sub _set_response_json : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP::Full->new_cgi } {}, undef, $out;
  $http->set_response_json ({"\x{4000}ab" => [123, "xyxz"]});
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json

{"\xe4\x80\x80ab":[123,"xyxz"]}};
} # _set_response_json

sub _set_response_json_undef : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP::Full->new_cgi } {}, undef, $out;
  $http->set_response_json (undef);
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json

null};
} # _set_response_json_undef

sub _set_response_json_scalar : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP::Full->new_cgi } {}, undef, $out;
  $http->set_response_json ("abcd\x{4000}");
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/json

"abcd\xe4\x80\x80"};
} # _set_response_json_scalar

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
