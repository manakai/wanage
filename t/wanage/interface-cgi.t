package test::Wanage::Interface::CGI;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Wanage::Interface::CGI;
use Test::MoreMore;
use Test::Wanage::Envs;

sub _version : Test(1) {
  ok $Wanage::Interface::CGI::VERSION;
} # _version

# ------ Request data ------

sub _url_scheme_no_env : Test(1) {
  my $cgi = with_cgi_env { Wanage::Interface::CGI->new_from_main };
  is $cgi->url_scheme, 'http';
} # _url_scheme_no_env

sub _url_scheme_with_https_empty : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => ''};
  is $cgi->url_scheme, 'http';
} # _url_scheme_with_https_empty

sub _url_scheme_with_https_on : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => 'ON'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_with_https_on

sub _url_scheme_with_https_on_lc : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => 'on'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_with_https_on_lc

sub _url_scheme_with_https_1 : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_with_https_1

sub _url_scheme_with_https_off : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => 'OFF'};
  is $cgi->url_scheme, 'http';
} # _url_scheme_with_https_off

sub _url_scheme_with_https_0 : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '0'};
  is $cgi->url_scheme, 'http';
} # _url_scheme_with_https_0

sub _url_scheme_x_forwarded_scheme_ignored : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_SCHEME => 'hoge'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_x_forwarded_scheme_ignored

sub _url_scheme_x_forwarded_scheme_proto_ignored : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_PROTo => 'hoge'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_x_forwarded_scheme_proto_ignored

sub _url_scheme_x_forwarded_scheme_used : Test(1) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_SCHEME => 'hoge'};
  is $cgi->url_scheme, 'hoge';
} # _url_scheme_x_forwarded_scheme_used

sub _url_scheme_x_forwarded_scheme_proto_used : Test(1) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_PROTO => 'hoge'};
  is $cgi->url_scheme, 'hoge';
} # _url_scheme_x_forwarded_scheme_proto_used

sub _url_scheme_x_forwarded_scheme_proto_used_bad : Test(1) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_PROTO => 'hoge@'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_x_forwarded_scheme_proto_used_bad

sub _url_scheme_x_forwarded_scheme_proto_used_both : Test(1) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_X_FORWARDED_PROTO => 'hoge',
     HTTP_X_FORWARDED_SCHEME => 'hage'};
  is $cgi->url_scheme, 'hage';
} # _url_scheme_x_forwarded_scheme_proto_used_both

sub _url_scheme_cf_visitor : Test(1) {
  local $Wanage::HTTP::UseCFVisitor = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_CF_VISITOR => '{"scheme":"http"}'};
  is $cgi->url_scheme, 'http';
} # _url_scheme_cf_visitor

sub _url_scheme_cf_visitor_and_xf : Test(1) {
  local $Wanage::HTTP::UseCFVisitor = 1;
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTP_CF_VISITOR => '{"scheme":"http"}',
     HTTP_X_FORWARDED_PROTO => 'https'};
  is $cgi->url_scheme, 'http';
} # _url_scheme_cf_visitor_and_xf

sub _url_scheme_cf_visitor_ignored : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {HTTPS => '1', HTTP_CF_VISITOR => '{"scheme":"http"}'};
  is $cgi->url_scheme, 'https';
} # _url_scheme_cf_visitor_ignored

sub _get_meta_variable : Test(2) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {
    REMOTE_ADDR => '192.168.1.21',
  };
  is $cgi->get_meta_variable ('REMOTE_ADDR'), '192.168.1.21';
  is $cgi->get_meta_variable ('remote_addr'), undef;
} # _get_meta_variable

sub _get_request_body_as_ref_no_data : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  };
  is $cgi->get_request_body_as_ref, undef;
} # _get_request_body_as_ref_no_data

sub _get_request_body_as_ref_zero_data : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 0}, '';
  is ${$cgi->get_request_body_as_ref}, '';
} # _get_request_body_as_ref_zero_data

sub _get_request_body_as_ref_small_data : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 10}, 'abcdefghjoilahgwegea';
  is ${$cgi->get_request_body_as_ref}, 'abcdefghjo';
} # _get_request_body_as_ref_small_data

sub _get_request_body_as_ref_too_short_data : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 100}, 'abcdefghjoilahgwegea';
  dies_here_ok {
    $cgi->get_request_body_as_ref;
  };
} # _get_request_body_as_ref_too_short_data

sub _get_request_body_as_ref_second_call : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 10}, 'abcdefghjoilahgwegea';
  $cgi->get_request_body_as_ref;
  dies_here_ok {
    $cgi->get_request_body_as_ref;
  };
} # _get_request_body_as_ref_second_call

sub _get_request_body_as_handle : Test(3) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 10}, 'abcdefghjoilahgwegea';
  my $fh = $cgi->get_request_body_as_handle;
  is scalar <$fh>, 'abcdefghjoilahgwegea';
  dies_here_ok {
    $cgi->get_request_body_as_ref;
  };
  dies_here_ok {
    $cgi->get_request_body_as_handle;
  };
} # _get_request_body_as_handle

sub _get_request_body_as_handle_after_ref : Test(1) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 10}, 'abcdefghjoilahgwegea';
  $cgi->get_request_body_as_ref;
  dies_here_ok {
    $cgi->get_request_body_as_handle;
  };
} # _get_request_body_as_handle

sub _get_request_header_content_length : Test(6) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {CONTENT_LENGTH => 10, HTTP_CONTENT_LENGTH => 20};
  is $cgi->get_request_header ('Content-Length'), 10;
  is $cgi->get_request_header ('Content-length'), 10;
  is $cgi->get_request_header ('CONTENT-LENGTH'), 10;
  is $cgi->get_request_header ('CONTENT_LENGTH'), undef;
  is $cgi->get_request_header ('HTTP_CONTENT_LENGTH'), undef;
  is $cgi->get_request_header ('Content_Length'), undef;
} # _get_request_header_content_length

sub _get_request_header_content_type : Test(6) {
  with_cgi_env {
    my $cgi = Wanage::Interface::CGI->new_from_main;
    is $cgi->get_request_header ('Content-Type'), 10;
    is $cgi->get_request_header ('Content-type'), 10;
    is $cgi->get_request_header ('CONTENT-TYPE'), 10;
    is $cgi->get_request_header ('CONTENT_TYPE'), undef;
    is $cgi->get_request_header ('HTTP_CONTENT_TYPE'), undef;
    is $cgi->get_request_header ('Content_Type'), undef;
  } {CONTENT_TYPE => 10, HTTP_CONTENT_TYPE => 'hoge'};
} # _get_request_header_content_type

sub _get_request_header_normal : Test(9) {
  my $cgi = with_cgi_env {
      Wanage::Interface::CGI->new_from_main;
  } {HTTP_ACCEPT_LANGUAGE => 'ja,en'};
  is $cgi->get_request_header ('Accept-Language'), 'ja,en';
  is $cgi->get_request_header ('Accept-language'), 'ja,en';
  is $cgi->get_request_header ('accept-language'), 'ja,en';
  is $cgi->get_request_header ('ACCEPT-LANGUAGE'), 'ja,en';
  is $cgi->get_request_header ('ACCEPT_LANGUAGE'), undef;
  is $cgi->get_request_header ('accept_language'), undef;
  is $cgi->get_request_header ('Accept'), undef;
  is $cgi->get_request_header ('Content-Type'), undef;
  is $cgi->get_request_header ('Content-Length'), undef;
} # _get_request_header_normal

sub _original_url_no_data : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, "http://:";
  is $cgi->canon_url->stringify, undef;
} # _original_url_no_data

sub _original_url_from_server : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hoge.Fuga:190';
  is $cgi->canon_url->stringify, 'http://hoge.fuga:190/';
} # _original_url_from_server

sub _original_url_from_server_https : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 80,
     SCRIPT_NAME => '', PATH_INFO => '/', HTTPS => 1};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'https://hoge.Fuga:80';
  is $cgi->canon_url->stringify, 'https://hoge.fuga:80/';
} # _original_url_from_server_https

sub _original_url_from_server_script_name : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '/ho%<ge>', PATH_INFO => '/<script>'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hoge.Fuga:190';
  is $cgi->canon_url->stringify, 'http://hoge.fuga:190/';
} # _original_url_from_server_script_name

sub _original_url_from_server_request_uri : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     REQUEST_URI => '/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hoge.Fuga:190/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://hoge.fuga:190/hoge%3Cscript%3E/fuga';
} # _original_url_from_server_request_uri

sub _original_url_from_http_host_request_uri : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => '/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://fuga:80/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://fuga/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri

sub _original_url_from_request_uri_pseudo_authority : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => '//hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://fuga:80//hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://fuga//hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_pseudo_authority

sub _original_url_from_request_uri_pseudo_authority2 : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => '///hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://fuga:80///hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://fuga///hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_pseudo_authority2

sub _original_url_from_http_host_request_uri_x_forwarded_host : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     HTTP_X_FORWARDED_HOST => 'abc:124',
     REQUEST_URI => '/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://fuga:80/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://fuga/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri_x_forwarded_host

sub _original_url_from_http_host_request_uri_x_forwarded_host_en : Test(4) {
  local $Wanage::HTTP::UseXForwardedHost = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     HTTP_X_FORWARDED_HOST => 'abc:0124',
     REQUEST_URI => '/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://abc:0124/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://abc:124/hoge%3Cscript%3E/fuga';
} # _original_url_from_http_host_request_uri_x_forwarded_host_en

sub _original_url_from_request_uri_abs : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => 'http://hogehoge:/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs

sub _original_url_from_request_uri_abs_https_not : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => 'https://hogehoge:/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_https_not

sub _original_url_from_request_uri_abs_https_really : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTPS => 'on',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => 'ftp://hogehoge:/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'https://hogehoge:/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'https://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_https_really

sub _original_url_from_request_uri_abs_non_http : Test(4) {
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => 'ftp://hogehoge:/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'http://hogehoge:/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'http://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_non_http

sub _original_url_from_request_uri_abs_non_http_use_scheme : Test(4) {
  local $Wanage::Interface::UseRequestURLScheme = 1;
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {SERVER_NAME => 'hoge.Fuga', SERVER_PORT => 190,
     SCRIPT_NAME => '', PATH_INFO => '/',
     HTTP_HOST => 'fuga:80',
     REQUEST_URI => 'ftp://hogehoge:/hoge<script>/fuga'};
  isa_ok $cgi->original_url, 'Wanage::URL';
  isa_ok $cgi->canon_url, 'Wanage::URL';
  is $cgi->original_url->stringify, 'ftp://hogehoge:/hoge<script>/fuga';
  is $cgi->canon_url->stringify, 'ftp://hogehoge/hoge%3Cscript%3E/fuga';
} # _original_url_from_request_uri_abs_non_http_use_scheme

# ------ Response ------

sub _set_status : Test(4) {
  for (
    ['Bad input' => 'Bad input'],
    ["Bad input\nabc" => 'Bad input abc'],
    ["Bad input\nabc\x0D def" => 'Bad input abc def'],
    ["\xFE\x{100}" => "\xc3\xbe\xc4\x80"],
  ) {
    my ($input, $expected) = @$_;
    my $out = '';
    my $cgi = with_cgi_env {
      Wanage::Interface::CGI->new_from_main;
    } {}, undef, $out;
    $cgi->send_response_headers (status => 400, status_text => $input);
    eq_or_diff $out, qq{Status: 400 $expected\n\n};
  }
} # _set_status

sub _set_status_twice : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response_headers (status => 402);
  dies_here_ok { $cgi->send_response_headers (status => 400) };
  $cgi->send_response_headers;
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 402 Payment Required\n\n};
} # _set_status_twice

sub _set_response_headers : Test(8) {
  for (
    [[] => qq{}],
    [[['Title' => 'HOge Fuga']] => qq{Title: HOge Fuga\n}],
    [[['Title' => 'HOge Fuga'], [Title => "\x{500}\x{2000}a"]] => qq{Title: HOge Fuga\nTitle: \xd4\x80\xe2\x80\x80a\n}],
    [[['Content-Type' => 'text/html; charset=euc-jp']] => qq{Content-Type: text/html; charset=euc-jp\n}],
    [[['Hoge' => "Fu\x0D\x0Aga"]] => qq{Hoge: Fu ga\n}],
    [[["Hoge\x00\x0A" => "Fu\x0D\x0Aga"]] => qq{Hoge__: Fu ga\n}],
    [[["Hog\x{1000}" => "Fu\x0D\x0Aga"]] => qq{Hog_: Fu ga\n}],
    [[['Content-TYPE' => '']] => qq{Content-TYPE: \n}],
  ) {
    my ($input, $expected) = @$_;
    my $out = '';
    my $cgi = with_cgi_env {
      Wanage::Interface::CGI->new_from_main;
    } {}, undef, $out;
    $cgi->send_response_headers (headers => $input);
    $cgi->send_response_headers;
    eq_or_diff $out, qq{Status: 200 OK\n$expected\n};
  }
} # _set_response_headers

sub _set_response_headers_twice : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response_headers (headers => [['Hoge' => 'Hoe']]);
  dies_here_ok {
    $cgi->send_response_headers (headers => [['Hoge' => 'Fuga']]);
  };
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 200 OK\nHoge: Hoe\n\n};
} # _set_response_headers_twice

sub _send_response_headers_empty : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 200 OK\n\n};
} # _send_response_headers_empty

sub _send_response_body : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body ('Hello, ');
  $cgi->send_response_body ('World.');
  $cgi->close_response_body;
  eq_or_diff $out, qq{Status: 200 OK\n\nHello, World.};
} # _send_response_body

sub _send_response_body_no_close : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body ("Hello, ");
  $cgi->send_response_body ("World.");
  eq_or_diff $out, qq{Status: 200 OK\n\nHello, World.};
} # _send_response_body_no_close

sub _send_response_body_print_after_close : Test(4) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body ("Hello, ");
  $cgi->close_response_body;
  dies_here_ok {
    $cgi->send_response_body ("World.");
  };
  dies_here_ok {
    $cgi->close_response_body;
  };
  eq_or_diff $out, qq{Status: 200 OK\n\nHello, };
} # _send_response_body_no_close

sub _send_response_body_header : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body ("Hello, ");
  $cgi->send_response_body ("World.");
  $cgi->close_response_body;
  dies_here_ok { $cgi->send_response_headers };
  eq_or_diff $out, qq{Status: 200 OK\n\nHello, World.};
} # _send_response_body_header

sub _send_response_send_response_headers : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main
  } {}, undef, $out;
  my $writer;
  $cgi->send_response;
  lives_ok {
    $cgi->send_response_headers;
  };
  eq_or_diff $out, qq{Status: 200 OK\n\n};
} # _send_response_send_response_body

sub _send_response_send_response_body : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response;
  lives_ok {
    $cgi->send_response_body ('abc');
  };
  eq_or_diff $out, qq{Status: 200 OK\n\nabc};
} # _send_response_send_response_body

sub _send_response_send_first : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response (onready => sub {
    $cgi->send_response_body ('abc');
  });
  eq_or_diff $out, qq{Status: 200 OK\n\nabc};
} # _send_response_send_first

sub _send_response_send_first_2 : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response (onready => sub {
    $cgi->send_response_headers (headers => [['abc' => 12]]);
    $cgi->send_response_body ('abc');
  });
  eq_or_diff $out, qq{Status: 200 OK\nabc: 12\n\nabc};
} # _send_response_send_first_2

sub _send_response_send_first_then_send : Test(8) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response (onready => sub {
    $cgi->send_response_body ('abc');
  });
  dies_here_ok { $cgi->send_response_headers (status => 440) };
  lives_ok { $cgi->send_response_headers };
  lives_ok { $cgi->send_response_body (120) };
  lives_ok { $cgi->close_response_body };
  dies_here_ok { $cgi->send_response_headers };
  dies_here_ok { $cgi->send_response_body (120) };
  dies_here_ok { $cgi->close_response_body };
  eq_or_diff $out, qq{Status: 200 OK\n\nabc120};
} # _send_response_send_first_then_send

sub _send_response_return : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  ng $cgi->send_response;
} # _send_response_return

sub _onclose_closed : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $invoked;
  $cgi->onclose (sub { $invoked = 1 });
  $cgi->close_response_body;
  
  ok $invoked;
} # _onclose_closed

sub _onclose_implicitclosed : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $invoked;
  $cgi->onclose (sub { $invoked = 1 });
  $cgi->send_response_headers;
  undef $cgi;
  
  ok $invoked;
} # _onclose_implicitclosed

sub _onclose_onready_implicitclosed : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $invoked;
  $cgi->send_response (onready => sub {
    $cgi->onclose (sub { $invoked = 1 });
    $cgi->send_response_headers;
  });
  undef $cgi;
  
  ok $invoked;
} # _onclose_onready_implicitclosed

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
