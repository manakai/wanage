package test::Wanage::Interface::PSGI;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Wanage::Interface::PSGI;
use Test::MoreMore;
use Test::Wanage::Envs;
use Encode;

sub _version : Test(1) {
  ok $Wanage::Interface::PSGI::VERSION;
} # _version

# ------ Request data ------

sub _url_scheme_no_env : Test(1) {
  my $env = new_psgi_env {};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->url_scheme, undef;
} # _url_scheme_no_env

sub _url_scheme_with_https : Test(1) {
  my $env = new_psgi_env {'psgi.url_scheme' => 'https'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->url_scheme, 'https';
} # _url_scheme_with_https

sub _url_scheme_x_forwarded_scheme_ignored : Test(1) {
  my $env = new_psgi_env {'psgi.url_scheme' => 'https',
                          HTTP_X_FORWARDED_SCHEME => 'hoge'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->url_scheme, 'https';
} # _url_scheme_x_forwarded_scheme_ignored

sub _url_scheme_x_forwarded_scheme_used : Test(1) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $env = new_psgi_env {'psgi.url_scheme' => 'https',
                          HTTP_X_FORWARDED_SCHEME => 'hoge'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->url_scheme, 'hoge';
} # _url_scheme_x_forwarded_scheme_used

sub _get_meta_variable : Test(2) {
  my $env = new_psgi_env {REMOTE_ADDR => '192.168.1.21'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->get_meta_variable ('REMOTE_ADDR'), '192.168.1.21';
  is $psgi->get_meta_variable ('remote_addr'), undef;
} # _get_meta_variable

sub _get_request_body_as_ref_no_data : Test(1) {
  my $env = new_psgi_env {};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->get_request_body_as_ref, undef;
} # _get_request_body_as_ref_no_data

sub _get_request_body_as_ref_zero_data : Test(1) {
  my $env = new_psgi_env {CONTENT_LENGTH => 0}, input_data => '';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is ${$psgi->get_request_body_as_ref}, '';
} # _get_request_body_as_ref_zero_data

sub _get_request_body_as_ref_small_data : Test(1) {
  my $env = new_psgi_env {CONTENT_LENGTH => 10},
      input_data => 'abcdefghjoilahgwegea';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is ${$psgi->get_request_body_as_ref}, 'abcdefghjo';
} # _get_request_body_as_ref_small_data

sub _get_request_body_as_ref_too_short_data : Test(1) {
  my $env = new_psgi_env {CONTENT_LENGTH => 100},
      input_data => 'abcdefghjoilahgwegea';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  dies_here_ok {
    $psgi->get_request_body_as_ref;
  };
} # _get_request_body_as_ref_too_short_data

sub _get_request_body_as_ref_second_call : Test(1) {
  my $env = new_psgi_env {CONTENT_LENGTH => 10},
      input_data => 'abcdefghjoilahgwegea';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  $psgi->get_request_body_as_ref;
  dies_here_ok {
    $psgi->get_request_body_as_ref;
  };
} # _get_request_body_as_ref_second_call

sub _get_request_body_as_handle : Test(3) {
  my $env = new_psgi_env {CONTENT_LENGTH => 10},
      input_data => 'abcdefghjoilahgwegea';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  my $fh = $psgi->get_request_body_as_handle;
  is scalar <$fh>, 'abcdefghjoilahgwegea';
  dies_here_ok {
    $psgi->get_request_body_as_ref;
  };
  dies_here_ok {
    $psgi->get_request_body_as_handle;
  };
} # _get_request_body_as_handle

sub _get_request_body_as_handle_after_ref : Test(1) {
  my $env = new_psgi_env {CONTENT_LENGTH => 10},
      input_data => 'abcdefghjoilahgwegea';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  $psgi->get_request_body_as_ref;
  dies_here_ok {
    $psgi->get_request_body_as_handle;
  };
} # _get_request_body_as_handle_after_ref

sub _get_request_header_content_length : Test(6) {
  my $env = new_psgi_env {CONTENT_LENGTH => 10, HTTP_CONTENT_LENGTH => 20};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->get_request_header ('Content-Length'), 10;
  is $psgi->get_request_header ('Content-length'), 10;
  is $psgi->get_request_header ('CONTENT-LENGTH'), 10;
  is $psgi->get_request_header ('CONTENT_LENGTH'), undef;
  is $psgi->get_request_header ('HTTP_CONTENT_LENGTH'), undef;
  is $psgi->get_request_header ('Content_Length'), undef;
} # _get_request_header_content_length

sub _get_request_header_content_type : Test(6) {
  my $env = new_psgi_env {CONTENT_TYPE => 10, HTTP_CONTENT_TYPE => 'hoge'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->get_request_header ('Content-Type'), 10;
  is $psgi->get_request_header ('Content-type'), 10;
  is $psgi->get_request_header ('CONTENT-TYPE'), 10;
  is $psgi->get_request_header ('CONTENT_TYPE'), undef;
  is $psgi->get_request_header ('HTTP_CONTENT_TYPE'), undef;
  is $psgi->get_request_header ('Content_Type'), undef;
} # _get_request_header_content_type

sub _get_request_header_normal : Test(9) {
  my $env = new_psgi_env {HTTP_ACCEPT_LANGUAGE => 'ja,en'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  is $psgi->get_request_header ('Accept-Language'), 'ja,en';
  is $psgi->get_request_header ('Accept-language'), 'ja,en';
  is $psgi->get_request_header ('accept-language'), 'ja,en';
  is $psgi->get_request_header ('ACCEPT-LANGUAGE'), 'ja,en';
  is $psgi->get_request_header ('ACCEPT_LANGUAGE'), undef;
  is $psgi->get_request_header ('accept_language'), undef;
  is $psgi->get_request_header ('Accept'), undef;
  is $psgi->get_request_header ('Content-Type'), undef;
  is $psgi->get_request_header ('Content-Length'), undef;
} # _get_request_header_normal

sub _original_url_no_data : Test(4) {
  my $env = new_psgi_env {};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, '://:';
  is $psgi->canon_url->stringify, undef;
} # _original_url_no_data

sub _original_url_from_server : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hoge.Fuga:190';
  is $psgi->canon_url->stringify, 'http://hoge.fuga:190/';
} # _original_url_from_server

sub _original_url_from_server_https : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 80,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          'psgi.url_scheme' => 'https'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'https://hoge.Fuga:80';
  is $psgi->canon_url->stringify, 'https://hoge.fuga:80/';
} # _original_url_from_server_https

sub _original_url_from_server_script_name : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '/ho%<ge>', PATH_INFO => '/<script>',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hoge.Fuga:190';
  is $psgi->canon_url->stringify, 'http://hoge.fuga:190/';
} # _original_url_from_server_script_name

sub _original_url_from_server_request_uri : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          REQUEST_URI => '/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hoge.Fuga:190/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://hoge.fuga:190/hoge%3Cscript%3E/fuga';
} # _original_url_from_server_request_uri

sub _original_url_from_http_host_request_uri : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => '/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://fuga:80/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://fuga/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri

sub _original_url_from_http_host_request_uri_x_forwarded : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          HTTP_X_FORWARDED_HOST => 'abc:0124',
                          REQUEST_URI => '/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://fuga:80/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://fuga/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri_x_forwarded

sub _original_url_from_http_host_request_uri_x_forwarded_en : Test(4) {
  local $Wanage::HTTP::UseXForwardedHost = 1;
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          HTTP_X_FORWARDED_HOST => 'abc:0123',
                          REQUEST_URI => '/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://abc:0123/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://abc:123/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri_x_forwarded_en

sub _original_url_from_request_uri_abs : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => 'http://hogehoge:/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs

sub _original_url_from_request_uri_abs_https_really : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => 'https://hogehoge:/hoge<script>/fuga',
                          'psgi.url_scheme' => 'https'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'https://hogehoge:/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'https://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_https_really

sub _original_url_from_request_uri_abs_https_not : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => 'https://hogehoge:/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_https_not

sub _original_url_from_request_uri_abs_non_http : Test(4) {
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => 'ftp://hogehoge:/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_non_http

sub _original_url_from_request_uri_abs_non_http_use_scheme : Test(4) {
  local $Wanage::Interface::UseRequestURLScheme = 1;
  my $env = new_psgi_env {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
                          SCRIPT_NAME => '', PATH_INFO => '/',
                          HTTP_HOST => 'fuga:80',
                          REQUEST_URI => 'ftp://hogehoge:/hoge<script>/fuga',
                          'psgi.url_scheme' => 'http'};
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ($env);
  isa_ok $psgi->original_url, 'Wanage::URL';
  isa_ok $psgi->canon_url, 'Wanage::URL';
  is $psgi->original_url->stringify, 'ftp://hogehoge:/hoge<script>/fuga';
  is $psgi->canon_url->stringify, 'ftp://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_non_http_use_scheme

# ------ Response ------

sub _set_status_nonstreamable_send_response_first : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 400, status_text => 'Bad input');
  });
  eq_or_diff $result, [400, [], []];
} # _set_status_nonstreamable_send_response_first

sub _set_status_nonstreamable_send_response_last : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_headers (status => 400, status_text => 'Bad input');
  my $result = $psgi->send_response;
  eq_or_diff $result, [400, [], []];
} # _set_status_nonstreamable_send_response_last

sub _set_status_streamable_send_response_first : Test(6) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ({
    'psgi.streaming' => 1,
  });
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 400, status_text => 'Bad input');
  });
  my $res;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [400, []];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
  
  $psgi->send_response_headers;
  eq_or_diff $res, [400, []];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _set_status_nonstreamable_send_response_first

sub _set_status_streamable_send_response_last : Test(6) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env ({
    'psgi.streaming' => 1,
  });
  $psgi->send_response_headers (status => 400, status_text => 'Bad input');
  my $result = $psgi->send_response;
  my $res;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [400, []];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
  
  $psgi->send_response_headers;
  eq_or_diff $res, [400, []];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _set_status_nonstreamable_send_response_last

sub _set_status_nonstreamable_twice : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_headers (status => 400, status_text => 'Bad input');
  dies_here_ok {
    $psgi->send_response_headers (status => 402, status_text => 'No payment');
  };
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  eq_or_diff $result, [400, [], []];
} # _set_status_nonstreamable_twice

sub _set_response_headers : Test(9) {
  for (
    [[]],
    [[['Title' => 'HOge Fuga']]],
    [[['Title' => 'HOge Fuga'], ['Title' => "\x{500}\x{2000}a"]] =>
     [['Title' => 'HOge Fuga'],
      ['Title' => encode 'utf-8', "\x{500}\x{2000}a"]]],
    [[['Content-Type' => 'text/html; charset=euc-jp']]],
    [[['Hoge' => "Fu\x0D\x0Aga"]] => [['Hoge' => "Fu ga"]]],
    [[['Hoge' => "Fu\x0D\x0A ga"]] => [['Hoge' => "Fu ga"]]],
    [[["Hoge\x00\x0A" => "Fu\x0D\x0Aga"]] => [["Hoge\x00 " => "Fu ga"]]],
    [[["Hog\x{1000}" => "Fu\x0D\x0Aga"]] =>
     [[(encode 'utf-8', "Hog\x{1000}") => "Fu ga"]]],
    [[['Content-TYPE' => '']]],
  ) {
    my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
    $psgi->send_response_headers (headers => $_->[0]);
    my $result = $psgi->send_response;
    eq_or_diff $result, [200, [map { @$_ } @{$_->[1] || $_->[0]}], []];
  }
} # _set_response_headers

sub _set_response_headers_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_headers (headers => [['Hoge' => 'Fuga']]);
  
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, [Hoge => 'Fuga']];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _set_response_headers_streamable

sub _set_response_headers_streamable_send_first : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (headers => [['Hoge' => 'Fuga']]);
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, [Hoge => 'Fuga']];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _set_response_headers_streamable_send_first

sub _set_response_headers_twice : Test(2) {
  my $out = '';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_headers (headers => [['Hoge' => 'Fuga']]);
  dies_here_ok {
    $psgi->send_response_headers (headers => [['Hoge' => 'Hoe']]);
  };
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, ['Hoge' => 'Fuga'], []];
} # _set_response_headers_twice

sub _set_response_headers_streamable_twice : Test(4) {
  my $out = '';
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_headers (headers => [['Hoge' => 'Fuga']]);
  dies_here_ok {
    $psgi->send_response_headers (headers => [['Hoge' => 'Hoe']]);
  };
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, ['Hoge' => 'Fuga']];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _set_response_headers_streamable_twice

sub _send_response_headers_empty : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], []];
} # _send_response_headers_empty

sub _send_response_headers_streamable_empty : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _send_response_headers_streamable_empty

sub _send_response_body : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_body ('abc');
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], ['abc']];
} # _send_response_body

sub _send_response_body_send_first : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
  });
  eq_or_diff $result, [200, [], ['abc']];
} # _send_response_body_send_first

sub _send_response_body_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_body ('abc');
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc'];
  ng $writer->closed;
} # _send_response_body_streamable

sub _send_response_body_streamable_send_first : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc'];
  ng $writer->closed;
} # _send_response_body_streamable_send_first

sub _send_response_body_then_response_headers : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_body ('abc');
  dies_here_ok { $psgi->send_response_headers (headers => [['Foo' => 1]]) };
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], ['abc']];
} # _send_response_body_then_response_headers

sub _send_response_body_then_response_headers_send_first : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
    dies_here_ok { $psgi->send_response_headers (headers => [['Foo' => 1]]) };
    $psgi->send_response_headers;
  });
  eq_or_diff $result, [200, [], ['abc']];
} # _send_response_body_then_response_headers_send_first

sub _send_response_body_then_response_headers_streamable : Test(4) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_body ('abc');
  dies_here_ok { $psgi->send_response_headers (headers => [['Foo' => 1]]) };
  $psgi->send_response_headers;
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc'];
  ng $writer->closed;
} # _send_response_body_then_response_headers_streamable

sub _send_response_body_then_response_headers_streamable_send_first : Test(4) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
    dies_here_ok { $psgi->send_response_headers (headers => [['Foo' => 1]]) };
    $psgi->send_response_headers;
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc'];
  ng $writer->closed;
} # _send_response_body_then_response_headers_streamable_send_first

sub _send_response_body_twice : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_body ('abc');
  $psgi->send_response_body ('xyz');
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], ['abc', 'xyz']];
} # _send_response_body_twice

sub _send_response_body_twice_send_first : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
    $psgi->send_response_body ('xyz');
  });
  eq_or_diff $result, [200, [], ['abc', 'xyz']];
} # _send_response_body_twice

sub _send_response_body_twice_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->send_response_body ('abc');
  $psgi->send_response_body ('xyz');
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc', 'xyz'];
  ng $writer->closed;
} # _send_response_body_twice_streamable

sub _send_response_body_twice_streamable_send_first : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_body ('abc');
    $psgi->send_response_body ('xyz');
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, ['abc', 'xyz'];
  ng $writer->closed;
} # _send_response_body_twice_streamable_send_first

sub _close_response_body : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  lives_ok { $psgi->close_response_body };
} # _close_response_body

sub _close_response_body_then_send : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->close_response_body;
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], []];
} # _close_response_body_then_send

sub _close_response_body_send_first : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->close_response_body;
  });
  eq_or_diff $result, [200, [], []];
} # _close_response_body_send_first

sub _close_response_body_then_send_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->close_response_body;
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, [];
  ok $writer->closed;
} # _close_response_body_then_send_streamable

sub _close_response_body_send_first_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->close_response_body;
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, [];
  ok $writer->closed;
} # _close_response_body_send_first_streamable

sub _close_response_body_twice : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->close_response_body;
  dies_here_ok { $psgi->close_response_body };
} # _close_response_body_twice

sub _close_response_body_twice_send_first : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response (onready => sub {
    $psgi->close_response_body;
    dies_here_ok { $psgi->close_response_body };
  });
} # _close_response_body_twice_send_first

sub _close_response_body_then_send_headers : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->close_response_body;
  dies_here_ok { $psgi->send_response_headers (headers => []) };
  dies_here_ok { $psgi->send_response_headers };
} # _close_response_body_then_send_headers

sub _close_response_body_then_send_body : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->close_response_body;
  dies_here_ok { $psgi->send_response_body ('abc') };
  eq_or_diff $psgi->send_response, [200, [], []];
} # _close_response_body_then_send_body

sub _close_response_body_then_send_body_streamable : Test(4) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  $psgi->close_response_body;
  dies_here_ok { $psgi->send_response_body ('abc') };
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, [];
  ok $writer->closed;
} # _close_response_body_then_send_body_streamable

sub _send_response_empty : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response;
  eq_or_diff $result, [200, [], []];
} # _send_response_empty

sub _send_response_empty_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  is $res, undef;
  eq_or_diff $writer->data, [];
  ng $writer->closed;
} # _send_response_empty_streamable

sub _send_response_twice : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response;
  dies_here_ok { $psgi->send_response };
  eq_or_diff $result, [200, [], []];
} # _send_response_twice

sub _send_response_send_first : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 501,
                                  headers => [[Foo => 12], [Bar => 3111]]);
    $psgi->send_response_headers;
    $psgi->send_response_body ('xyz');
    $psgi->send_response_body ('abcx');
  });
  eq_or_diff $result, [501, [Foo => 12, Bar => 3111], ['xyz', 'abcx']];
} # _send_response_send_first

sub _send_response_send_first_streamable : Test(3) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 501,
                                  headers => [[Foo => 12], [Bar => 3111]]);
    $psgi->send_response_headers;
    $psgi->send_response_body ('xyz');
    $psgi->send_response_body ('abcx');
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [501, [Foo => 12, Bar => 3111]];
  eq_or_diff $writer->data, ['xyz', 'abcx'];
  ng $writer->closed;
} # _send_response_send_first_stremable

sub _send_response_send_first_twice : Test(2) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    dies_here_ok { $psgi->send_response };
  });
  eq_or_diff $result, [200, [], []];
} # _send_response_send_first_twice

sub _send_response_send_first_closed : Test(5) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 501,
                                  headers => [[Foo => 12], [Bar => 3111]]);
    $psgi->send_response_headers;
    $psgi->send_response_body ('xyz');
    $psgi->send_response_body ('abcx');
    $psgi->close_response_body;
    dies_here_ok { $psgi->send_response_body ('123') };
    dies_here_ok { $psgi->close_response_body };
  });
  dies_here_ok { $psgi->send_response_body ('123') };
  dies_here_ok { $psgi->close_response_body };
  eq_or_diff $result, [501, [Foo => 12, Bar => 3111], ['xyz', 'abcx']];
} # _send_response_send_first_closed

sub _send_response_send_first_streamable_closed : Test(7) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 501,
                                  headers => [[Foo => 12], [Bar => 3111]]);
    $psgi->send_response_headers;
    $psgi->send_response_body ('xyz');
    $psgi->send_response_body ('abcx');
    $psgi->close_response_body;
    dies_here_ok { $psgi->send_response_body ('123') };
    dies_here_ok { $psgi->close_response_body };
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [501, [Foo => 12, Bar => 3111]];
  eq_or_diff $writer->data, ['xyz', 'abcx'];
  ok $writer->closed;

  dies_here_ok { $psgi->send_response_body ('123') };
  dies_here_ok { $psgi->close_response_body };
} # _send_response_send_first_stremable_closed

sub _send_response_send_first_streamable_closed_2 : Test(8) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $result = $psgi->send_response (onready => sub {
    dies_here_ok { $psgi->send_response_headers
                       (status => 501,
                        headers => [[Foo => 12], [Bar => 3111]]) };
    dies_here_ok { $psgi->send_response_headers };
    dies_here_ok { $psgi->send_response_body ('xyz') };
    dies_here_ok { $psgi->send_response_body ('abcx') };
    dies_here_ok { $psgi->close_response_body };
  });
  $psgi->send_response_headers (status => 300);
  $psgi->send_response_body ('661');
  $psgi->close_response_body;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  eq_or_diff $res, [300, []];
  eq_or_diff $writer->data, ['661'];
  ok $writer->closed;
} # _send_response_send_first_stremable_closed_2

sub _send_response_implicitly_closed : Test(4) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  $psgi->send_response_headers (status => 501,
                                headers => [[Foo => 12], [Bar => 3111]]);
  $psgi->send_response_headers;
  $psgi->send_response_body ('xyz');
  $psgi->send_response_body ('abcx');
  my $result = $psgi->send_response;
  dies_here_ok { $psgi->send_response_body ('xxxaa') }; 
  dies_here_ok { $psgi->close_response_body }; 
  dies_here_ok { $psgi->send_response_body ('xxxaa') }; 
  eq_or_diff $result, [501, [Foo => 12, Bar => 3111], ['xyz', 'abcx']];
} # _send_response_implicitly_closed

sub _send_response_send_first_implicitly_closed : Test(4) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 501,
                                  headers => [[Foo => 12], [Bar => 3111]]);
    $psgi->send_response_headers;
    $psgi->send_response_body ('xyz');
    $psgi->send_response_body ('abcx');
  });
  dies_here_ok { $psgi->send_response_body ('xxxaa') }; 
  dies_here_ok { $psgi->close_response_body }; 
  dies_here_ok { $psgi->send_response_body ('xxxaa') }; 
  eq_or_diff $result, [501, [Foo => 12, Bar => 3111], ['xyz', 'abcx']];
} # _send_response_send_first_implicitly_closed

sub _onclose_nonstream_close_send : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $invoked;
  $psgi->onclose (sub { $invoked = 1 });
  $psgi->close_response_body;
  $psgi->send_response;

  ok $invoked;
} # _onclose_nonstream_close_send

sub _onclose_nonstream_onready_close : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $invoked;
  $psgi->send_response (onready => sub {
    $psgi->onclose (sub { $invoked = 1 });
    $psgi->close_response_body;
  });

  ok $invoked;
} # _onclose_nonstream_onready_close

sub _onclose_nonstream_send_implicitclose : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env;
  my $invoked;
  $psgi->onclose (sub { $invoked = 1 });
  $psgi->send_response;
  undef $psgi;

  ok $invoked;
} # _onclose_nonstream_send_implicitclose

sub _onclose_streamable_onready_close : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $invoked;
  $psgi->onclose (sub { $invoked = 1 });
  my $result = $psgi->send_response (onready => sub {
    $psgi->send_response_headers (status => 300);
    $psgi->send_response_body ('661');
    $psgi->close_response_body;
  });
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });

  ok $invoked;
} # _onclose_streamable_onready_send

sub _onclose_streamable_send_close : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $invoked;
  $psgi->onclose (sub { $invoked = 1 });
  $psgi->send_response_headers (status => 300);
  $psgi->send_response_body ('661');
  $psgi->close_response_body;
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });

  ok $invoked;
} # _onclose_streamable_send_close

sub _onclose_streamable_send_implicitclose : Test(1) {
  my $psgi = Wanage::Interface::PSGI->new_from_psgi_env
      ({'psgi.streaming' => 1});
  my $invoked;
  $psgi->onclose (sub { $invoked = 1 });
  $psgi->send_response_headers (status => 300);
  $psgi->send_response_body ('661');
  my $result = $psgi->send_response;
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $result->(sub { $res = shift; return $writer });
  undef $psgi;
  undef $result;

  ok $invoked;
} # _onclose_streamable_send_implicitclose

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
