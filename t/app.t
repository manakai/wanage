package test::Wanage::App;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('t', 'lib')->stringify;
use Test::Wanage::Envs;
use base qw(Test::Class);
use Wanage::App;
use Wanage::HTTP;
use Test::MoreMore;
use Encode;

sub _version : Test(1) {
  ok $Wanage::App::VERSION;
} # _version

sub _new_from_http : Test(3) {
  my $http = with_cgi_env { Wanage::HTTP->new_cgi };
  my $app = Wanage::App->new_from_http ($http);
  isa_ok $app, 'Wanage::App';
  my $http2 = $app->http;
  isa_ok $http2, 'Wanage::HTTP';
  is $http2, $http;
} # _new_from_http

sub _path_segments : Test(60) {
  for my $test (
    [undef, ['']],
    ['' => ['']],
    ['0' => []],
    ['1' => []],
    ['a' => []],
    ['foo' => []],
    ['/' => ['']],
    ['/index' => ['index']],
    ['/foo' => ['foo']],
    ['/foo/' => ['foo', '']],
    ['/foo//' => ['foo', '', '']],
    ['/0' => ['0']],
    ['/foo/bar' => ['foo', 'bar']],
    ['/foo%2Fbar' => ['foo/bar']],
    ['/hoge.abc' => ['hoge.abc']],
    [(encode 'utf8', "/foo%25ab%9Eab\x{4e00}")
     => ["foo%ab\x{FFFD}ab\x{4E00}"]],
    [(encode 'utf8', "/\x{FFFF}") => ["\x{FFFD}"]],
    ['/%EF%AC%AX' => ["\x{FFFD}\x{FFFD}%AX"]],
    ['/%EF%AC%AD' => ["\x{FB2D}"]],
    ['/foo/../bar/%2E' => ["bar", '']],
    ['///\a' => ['']],
    ['///\a/b' => ['b']],
    ['/a///\a' => ['a', '', '', '', 'a']],
    ['/http://[foo]:31//\a?hoge#fuga'
     => ['http:', '', '[foo]:31', '', '', 'a']],
    ['/?///\a' => ['']],
    ['?///\a' => ['']],
    ['/ab%9Fa%A0%00' => ["ab\x{FFFD}a\x{FFFD}\x00"]],
    ['*' => []],
    ['foo.bar.baz' => []],
    ['foo.bar.baz:81' => []],
  ) {
    my $http = with_cgi_env { Wanage::HTTP->new_cgi }
        {REQUEST_URI => $test->[0], SERVER_NAME => 'hoge', SERVER_PORT => 80};
    my $app = Wanage::App->new_from_http ($http);
    my $paths = $app->path_segments;
    isa_list_ok $paths;
    eq_or_diff $paths->to_a, $test->[1];
  }
} # _path_segments

sub _text_param_from_query : Test(10) {
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {QUERY_STRING => 'hoge=fuga&FOO=foo&foo=bar&foo=baz&abc=&def'};
  my $app = Wanage::App->new_from_http ($http);
  is $app->text_param ('fage'), undef;
  is $app->text_param ('hoge'), 'fuga';
  is $app->text_param ('foo'), 'bar';
  is $app->text_param ('abc'), '';
  is $app->text_param ('def'), '';
  eq_or_diff $app->text_param_list ('fage')->to_a, [];
  eq_or_diff $app->text_param_list ('hoge')->to_a, ['fuga'];
  eq_or_diff $app->text_param_list ('foo')->to_a, ['bar', 'baz'];
  eq_or_diff $app->text_param_list ('abc')->to_a, [''];
  eq_or_diff $app->text_param_list ('def')->to_a, [''];
} # _text_param_from_query

sub _text_param_from_body : Test(10) {
  my $stdin = 'hoge=fuga&FOO=foo&foo=bar&foo=baz&abc=&def';
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {CONTENT_TYPE => 'application/x-www-form-urlencoded',
     CONTENT_LENGTH => length $stdin}, $stdin;
  my $app = Wanage::App->new_from_http ($http);
  is $app->text_param ('fage'), undef;
  is $app->text_param ('hoge'), 'fuga';
  is $app->text_param ('foo'), 'bar';
  is $app->text_param ('abc'), '';
  is $app->text_param ('def'), '';
  eq_or_diff $app->text_param_list ('fage')->to_a, [];
  eq_or_diff $app->text_param_list ('hoge')->to_a, ['fuga'];
  eq_or_diff $app->text_param_list ('foo')->to_a, ['bar', 'baz'];
  eq_or_diff $app->text_param_list ('abc')->to_a, [''];
  eq_or_diff $app->text_param_list ('def')->to_a, [''];
} # _text_param_from_body

sub _text_param_both : Test(2) {
  my $stdin = 'hoge=fuga';
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {QUERY_STRING => 'hoge=abc',
     CONTENT_TYPE => 'application/x-www-form-urlencoded',
     CONTENT_LENGTH => length $stdin}, $stdin;
  my $app = Wanage::App->new_from_http ($http);
  is $app->text_param ('hoge'), 'abc';
  eq_or_diff $app->text_param_list ('hoge')->to_a, ['abc', 'fuga'];
} # _text_param_both

sub _text_param_utf8 : Test(12) {
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {QUERY_STRING => 'hoge=%E4%B8%80&fuga=%84%B8%81&%E4%B8%80=abc&%80=%00'};
  my $app = Wanage::App->new_from_http ($http);
  is $app->text_param ('hoge'), "\x{4E00}";
  is $app->text_param ('fuga'), "\x{FFFD}\x{FFFD}\x{FFFD}";
  is $app->text_param ("\xE4\xB8\x80"), undef;
  is $app->text_param ("\x{4E00}"), 'abc';
  is $app->text_param ("\x80"), undef;
  is $app->text_param ("\x{FFFD}"), undef;
  eq_or_diff $app->text_param_list ('hoge')->to_a, ["\x{4E00}"];
  eq_or_diff $app->text_param_list ('fuga')->to_a,
      ["\x{FFFD}\x{FFFD}\x{FFFD}"];
  eq_or_diff $app->text_param_list ("\xE4\xB8\x80")->to_a, [];
  eq_or_diff $app->text_param_list ("\x{4E00}")->to_a, ['abc'];
  eq_or_diff $app->text_param_list ("\x80")->to_a, [];
  eq_or_diff $app->text_param_list ("\x{FFFD}")->to_a, [];
} # _text_param_utf8

sub _text_param_list : Test(2) {
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {QUERY_STRING => 'hoge=fuga&FOO=foo&foo=bar&foo=baz&abc=&def'};
  my $app = Wanage::App->new_from_http ($http);
  my $list = $app->text_param_list ('hoge');
  isa_list_ok $list;
  is $app->text_param_list ('hoge'), $list;
} # _text_param_list

## ------ Response construction ------

sub _send_plain_text : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_plain_text ("\x{5000}\x{fe}\x{50}\x00");
  dies_here_ok {
    $app->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: text/plain; charset=utf-8

\xe5\x80\x80\xc3\xbeP\x00};
} # _send_plain_text

sub _send_html : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_html ("\x{5000}\x{fe}\x{50}\x00");
  dies_here_ok {
    $app->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: text/html; charset=utf-8

\xe5\x80\x80\xc3\xbeP\x00};
} # _send_html

sub _send_redirect_no_args : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    REQUEST_URI => q<https://hogehoge.test:0123/foo/b%61r/baz?a=b&c=">,
  }, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_redirect;
  eq_or_diff $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: https://hogehoge.test:123/foo/bar/baz?a=b&c=%22

<!DOCTYPE HTML><title>Moved</title><a href="https://hogehoge.test:123/foo/bar/baz?a=b&amp;c=%22">Moved</a>};
} # _send_redirect_no_args

sub _send_redirect_relative : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    REQUEST_URI => q<https://hogehoge.test:0123/foo/b%61r/baz?a=b&c=">,
  }, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_redirect (q<../hoge/fug&a>);
  eq_or_diff $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: https://hogehoge.test:123/foo/hoge/fug&a

<!DOCTYPE HTML><title>Moved</title><a href="https://hogehoge.test:123/foo/hoge/fug&amp;a">Moved</a>};
} # _send_redirect_relative

sub _send_redirect_abspath : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    REQUEST_URI => q<https://hogehoge.test:0123/foo/b%61r/baz?a=b&c=">,
  }, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_redirect (q</hoge/fuga#abc>);
  eq_or_diff $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: https://hogehoge.test:123/hoge/fuga#abc

<!DOCTYPE HTML><title>Moved</title><a href="https://hogehoge.test:123/hoge/fuga#abc">Moved</a>};
} # _send_redirect_abspath

sub _send_redirect_absurl : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    REQUEST_URI => q<https://hogehoge.test:0123/foo/b%61r/baz?a=b&c=">,
  }, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_redirect (q<httP://abc.TEST/hoge/fuga#abc>);
  eq_or_diff $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: http://abc.test/hoge/fuga#abc

<!DOCTYPE HTML><title>Moved</title><a href="http://abc.test/hoge/fuga#abc">Moved</a>};
} # _send_redirect_absurl

sub _send_redirect_filtered : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    REQUEST_URI => q<https://hogehoge.test:0123/foo/b%61r/baz?a=b&c=">,
  }, undef, $out;
  {
    package test::_send_redirect_response_filtered::app;
    push our @ISA, qw(Wanage::App);
    sub redirect_url_filter {
      my $url = $_[1];
      $url->{scheme} = 'ftp';
      $url->{path} .= '/HOGE';
      return $url;
    }
  }
  my $app = test::_send_redirect_response_filtered::app->new_from_http ($http);
  $app->send_redirect (q<httP://abc.TEST/hoge/fuga#abc>);
  eq_or_diff $out, q{Status: 302 Found
Content-Type: text/html; charset=utf-8
Location: ftp://abc.test/hoge/fuga/HOGE#abc

<!DOCTYPE HTML><title>Moved</title><a href="ftp://abc.test/hoge/fuga/HOGE#abc">Moved</a>};
} # _send_redirect_filtered

sub _send_error_no_args : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_error;
  eq_or_diff $out, q{Status: 400 Bad Request
Content-Type: text/plain; charset=us-ascii

400};
} # _send_error_no_args

sub _send_error_with_code : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_error (410);
  eq_or_diff $out, q{Status: 410 Gone
Content-Type: text/plain; charset=us-ascii

410};
} # _send_error_with_code

sub _send_error_with_code_and_reason : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_error (410, reason_phrase => "The page was\nremoved!");
  eq_or_diff $out, q{Status: 410 The page was removed!
Content-Type: text/plain; charset=us-ascii

410};
} # _send_error_with_code_and_reason

sub _send_error_with_code_and_reason_utf8 : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = Wanage::App->new_from_http ($http);
  $app->send_error (410, reason_phrase => "\x{5000}\x{5100}\x00");
  eq_or_diff $out, encode 'utf-8', qq{Status: 410 \x{5000}\x{5100}\x00
Content-Type: text/plain; charset=us-ascii

410};
} # _send_error_with_code_and_reason_utf8

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
