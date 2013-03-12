package test::Wanage::HTTP;
use strict;
use warnings;
no warnings 'once';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Wanage::HTTP;
use base qw(Test::Class);
use Encode;
use Test::MoreMore;
use Test::Wanage::Envs;

$Wanage::HTTP::Sortkeys = 1;

sub _version : Test(1) {
  ok $Wanage::HTTP::VERSION;
} # _version

# ------ Constructors ------

sub _new_cgi : Test(3) {
  my $http = with_cgi_env {
    Wanage::HTTP->new_cgi;
  } {HTTP_HOGE => 123};
  isa_ok $http, 'Wanage::HTTP';
  isa_ok $http->{interface}, 'Wanage::Interface::CGI';
  is $http->get_request_header ('Hoge'), '123';
} # _new_cgi

sub _new_from_psgi_env : Test(3) {
  my $env = new_psgi_env {HTTP_HOGE => 123};
  my $http = Wanage::HTTP->new_from_psgi_env ($env);
  isa_ok $http, 'Wanage::HTTP';
  isa_ok $http->{interface}, 'Wanage::Interface::PSGI';
  is $http->get_request_header ('Hoge'), '123';
} # _new_from_psgi_env

# ------ Request URL ------

sub _url : Test(14) {
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>, REQUEST_URI => "/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'http'};
  for my $http (@$https) {
    my $url = $http->url;
    isa_ok $url, 'Wanage::URL';
    is $url->{scheme}, 'http';
    is $url->{host}, 'hoge.test';
    is $url->{path}, q</hoge/>;
    is $url->{query}, q<abc%EF%BF%BD%EF%BF%BD>;
    is $http->url, $url;
    isnt $http->original_url, $url;
  }
} # _url

sub _url_x_forwarded_scheme_ignored : Test(4) {
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>, REQUEST_URI => "/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'hoge'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'https';
    is $http->original_url->{scheme}, 'https';
  }
} # _url_x_forwarded_scheme_ignored

sub _url_x_forwarded_scheme_used : Test(4) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>, REQUEST_URI => "/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'hoge'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'hoge';
    is $http->original_url->{scheme}, 'hoge';
  }
} # _url_x_forwarded_scheme_used

sub _url_x_forwarded_scheme_bad : Test(4) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>, REQUEST_URI => "/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'hoge,fuga'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'https';
    is $http->original_url->{scheme}, 'https';
  }
} # _url_x_forwarded_scheme_bad

sub _url_x_forwarded_scheme_request_uri : Test(4) {
  local $Wanage::Interface::UseRequestURLScheme = 1;
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>,
              REQUEST_URI => "ftp://aa/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'hoge,fuga'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'ftp';
    is $http->original_url->{scheme}, 'ftp';
  }
} # _url_x_forwarded_scheme_request_uri

sub _url_x_forwarded_scheme_request_uri_2 : Test(4) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>,
              REQUEST_URI => "ftp://aa/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'hoge,fuga'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'https';
    is $http->original_url->{scheme}, 'https';
  }
} # _url_x_forwarded_scheme_request_uri_2

sub _url_x_forwarded_scheme_request_uri_3 : Test(4) {
  local $Wanage::HTTP::UseXForwardedScheme = 1;
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>,
              REQUEST_URI => "ftp://aa/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'https', HTTPS => 'on',
              HTTP_X_FORWARDED_SCHEME => 'http'};
  for my $http (@$https) {
    is $http->url->{scheme}, 'http';
    is $http->original_url->{scheme}, 'http';
  }
} # _url_x_forwarded_scheme_request_uri_3

sub _original_url : Test(14) {
  my $https = new_https_for_interfaces
      env => {HTTP_HOST => q<hoge.TEST>, REQUEST_URI => "/hoge/?abc\xFE\xC5",
              'psgi.url_scheme' => 'http'};
  for my $http (@$https) {
    my $url = $http->original_url;
    isa_ok $url, 'Wanage::URL';
    is $url->{scheme}, 'http';
    is $url->{host}, 'hoge.TEST';
    is $url->{path}, q</hoge/>;
    is $url->{query}, qq<abc\x{FFFD}\x{FFFD}>;
    is $http->original_url, $url;
    isnt $http->url, $url;
  }
} # _original_url

sub _query_params : Test(14) {
  for (
    [undef, {}],
    ['' => {}],
    ['0' => {'0' => [""]}],
    ['abc=%26%A9' => {abc => ["&\xA9"]}],
    ['hoge=xy&hoge=aa' => {hoge => ["xy", "aa"]}],
    ["aaa=bbb&ccc=dd;" => {'' => [''], aaa => ["bbb"], ccc => ["dd"]}],
    ["===" => {'' => ["=="]}],
  ) {
    my $https = new_https_for_interfaces
        env => {QUERY_STRING => $_->[0]};
    for my $http (@$https) {
      eq_or_diff $http->query_params, $_->[1];
    }
  }
} # _query_params

sub _query_params_same : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    is $http->query_params, $http->query_params;
  }
} # _query_params_same

# ------ Request method ------

sub _request_method : Test(78) {
  for (
    [undef, undef, 0, 0],
    ['' => '', 0, 0],
    ['0' => '0', 0, 0],
    ['GET' => 'GET', 1, 1],
    ['get' => 'GET', 1, 1],
    ['Get' => 'GET', 1, 1],
    ['POST' => 'POST', 0, 0],
    ['HEAD' => 'HEAD', 1, 1],
    ['PUT' => 'PUT', 0, 1],
    ['DELETE' => 'DELETE', 0, 1],
    ['OPTIONS' => 'OPTIONS', 0, 1],
    ['unknown method' => 'unknown method', 0, 0],
    ['Get123' => 'Get123', 0, 0],
  ) {
    my $https = new_https_for_interfaces
        env => {REQUEST_METHOD => $_->[0]};
    for my $http (@$https) {
      is $http->request_method, $_->[1];
      is_bool $http->request_method_is_safe, $_->[2];
      is_bool $http->request_method_is_idempotent, $_->[3];
    }
  }
} # _request_method

# ------ Request headers ------

sub _get_request_header : Test(10) {
  my $https = new_https_for_interfaces
      env => {HTTP_HOGE_FUGA => 'abc def,abc',
              CONTENT_TYPE => 'text/html',
              CONTENT_LENGTH => 351,
              HTTP_AUTHORIZATION => 'hoge fauga'};
  for my $http (@$https) {
    is $http->get_request_header ('Hoge-Fuga'), 'abc def,abc';
    is $http->get_request_header ('X-hoge-fuga'), undef;
    is $http->get_request_header ('Content-Type'), 'text/html';
    is $http->get_request_header ('Content-Length'), 351;
    is $http->get_request_header ('Authorization'), 'hoge fauga';
  }
} # _get_request_header

sub _client_ip_addr : Test(6) {
  my $https = new_https_for_interfaces
      env => {REMOTE_ADDR => '19.51.34.123'};
  for my $http (@$https) {
    my $ip = $http->client_ip_addr;
    isa_ok $ip, 'Wanage::HTTP::ClientIPAddr';
    is $ip->as_text, '19.51.34.123';
    is $http->client_ip_addr, $ip;
  }
} # _client_ip_addr

sub _client_ip_addr_custom : Test(4) {
  {
    package test::http::Wanage::HTTP::ClientIPAddr;
    push our @ISA, 'Wanage::HTTP::ClientIPAddr';
    $INC{'test/http/Wanage/HTTP/ClientIPAddr.pm'} = 1;
    require Wanage::HTTP::ClientIPAddr;
    sub select_addr { '40.13.11.41' }
  }
  local $Wanage::HTTP::ClientIPAddrClass
      = 'test::http::Wanage::HTTP::ClientIPAddr';
  my $https = new_https_for_interfaces
      env => {REMOTE_ADDR => '19.51.34.123'};
  for my $http (@$https) {
    my $ip = $http->client_ip_addr;
    isa_ok $ip, 'test::http::Wanage::HTTP::ClientIPAddr';
    is $ip->as_text, '40.13.11.41';
  }
} # _client_ip_addr_custom

sub _client_ip_addr_x_forwarded_for_ignored : Test(6) {
  my $https = new_https_for_interfaces
      env => {REMOTE_ADDR => '19.51.34.123',
              HTTP_X_FORWARDED_FOR => '20.51.112.31'};
  for my $http (@$https) {
    my $ip = $http->client_ip_addr;
    isa_ok $ip, 'Wanage::HTTP::ClientIPAddr';
    is $ip->as_text, '19.51.34.123';
    is $http->client_ip_addr, $ip;
  }
} # _client_ip_addr_x_forwarded_for_ignored

sub _client_ip_addr_x_forwarded_for_used : Test(6) {
  local $Wanage::HTTP::UseXForwardedFor = 1;
  my $https = new_https_for_interfaces
      env => {REMOTE_ADDR => '19.51.34.123',
              HTTP_X_FORWARDED_FOR => '20.51.112.31'};
  for my $http (@$https) {
    my $ip = $http->client_ip_addr;
    isa_ok $ip, 'Wanage::HTTP::ClientIPAddr';
    is $ip->as_text, '20.51.112.31';
    is $http->client_ip_addr, $ip;
  }
} # _client_ip_addr_x_forwarded_for_used

sub _ua : Test(6) {
  my $https = new_https_for_interfaces
      env => {HTTP_USER_AGENT => 'mybot'};
  for my $http (@$https) {
    my $ua = $http->ua;
    isa_ok $ua, 'Wanage::HTTP::UA';
    ok $ua->is_bot;
    is $http->ua, $ua;
  }
} # _ua

sub _ua_custom : Test(4) {
  {
    package test::http::Wanage::HTTP::UA;
    push our @ISA, 'Wanage::HTTP::UA';
    $INC{'test/http/Wanage/HTTP/UA.pm'} = 1;
    require Wanage::HTTP::UA;
    sub is_mine { 1 }
  }
  local $Wanage::HTTP::UAClass = 'test::http::Wanage::HTTP::UA';
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    my $ua = $http->ua;
    isa_ok $ua, 'test::http::Wanage::HTTP::UA';
    ok $ua->is_mine;
  }
} # _ua_custom

sub _request_mime_type : Test(6) {
  my $https = new_https_for_interfaces
      env => {CONTENT_TYPE => 'text/HTML; Charset=ISO-8859-1'};
  for my $http (@$https) {
    my $mime = $http->request_mime_type;
    is $mime->value, 'text/html';
    is $mime->params->{charset}, 'ISO-8859-1';
    is $http->request_mime_type, $mime;
  }
} # _request_mime_type

sub _accept_langs : Test(100) {
  for my $test (
    [undef, []],
    ['' => []],
    ['*' => ['*']],
    ['ja,*' => [qw/ja */]],
    ['ja' => [qw/ja/]],
    ['ja,en' => [qw/ja en/]],
    ['ja , en-gb' => [qw/ja en-gb/]],
    ['ja;q=0,en' => [qw/en/]],
    ['ja;q=0.3,en;q=0.9' => [qw/en ja/]],
    ['ja;q=0.0001,en;q=0.0014' => [qw/en/]],
    ['ja;q=3,en;q=5' => [qw/ja en/]],
    ['ja;q="0.004",en;q="0.005"' => [qw/en ja/]],
    ['ja;q="0.004"an,en;q="0.005"' => [qw/en ja/]],
    ['ja;q="0.00\\4",en;q="0.00\\5"' => []],
    ['ja;qa=0.44,en;qb=0.66' => [qw/ja en/]],
    ['ja;qa=0.44;q=0.9,en;qb=0.66;q=0.99' => [qw/en ja/]],
    ['ja;qa=0.44;q=0.9;a=1,en;qb=0.66;q=0.99' => [qw/en ja/]],
    ['ja;qa=0.44;Q=0.9,en;qb=0.66;Q=0.99' => [qw/en ja/]],
    ['ja ; ; q  = 0.9  ,  en ; q  =  0.99 ;' => [qw/en ja/]],
    ['  ja  ;q,en  ;q=0.9' => [qw/ja en/]],
    ['ja;q="0.9,en=0.8",fr' => [qw/fr ja/]],
    ['ja;q=0.9,en;q=0.8,JA;q=0.6' => [qw/ja en/]],
    ['ja;q=0.9,en;q=0.8,JA;q=0.0' => [qw/ja en/]],
    ['ja;q=0.9,en;notq=0.3' => [qw/en ja/]],
    ['ja;q=0.9,,en;q=0.01,' => [qw/ja en/]],
  ) {
    my $https = new_https_for_interfaces
        env => {HTTP_ACCEPT_LANGUAGE => $test->[0]};
    for my $http (@$https) {
      my $list = $http->accept_langs;
      isa_list_ok $list;
      eq_or_diff $list->to_a, $test->[1];
    }
  }
} # _accept_langs

sub _accept_langs_twice : Test(2) {
  my $https = new_https_for_interfaces
      env => {HTTP_ACCEPT_LANGUAGE => 'ja'};
  for my $http (@$https) {
    my $list = $http->accept_langs;
    is $http->accept_langs, $list;
  }
} # _accept_langs_twice

sub _request_cookies : Test(72) {
  for my $test (
    [undef, {}],
    ['' => {}],
    ['0' => {}],
    ['=def;abc=ddd' => {abc => 'ddd'}],
    ['0=def' => {0 => 'def'}],
    ['abc=def' => {abc => 'def'}],
    ['abc=def;xyz=aaa' => {abc => 'def', xyz => 'aaa'}],
    ['abc=def;abc=xyz' => {abc => 'def'}],
    ['abc=def; xaya=abc' => {abc => 'def', xaya => 'abc'}],
    [' aa  = bbb ; xxy = hrr ' => {aa => 'bbb', xxy => 'hrr'}],
    ['AbCA = aAWA' => {AbCA => 'aAWA'}],
    ['ab   aaaa = ea aa  rr' => {'ab   aaaa' => 'ea aa  rr'}],
    ['"abc def"="xyz aaa"' => {'"abc def"' => '"xyz aaa"'}],
    ['abc=def;xyz' => {'abc' => 'def'}],
    ['abac=dee;;aaa=xyz;' => {'abac' => 'dee', 'aaa' => 'xyz'}],
    ["\x98\x00\xCDab=\xAA\xFF\x00\x12" => {"\x98\x00\xCDab" => "\xAA\xFF\x00\x12"}],
    ['abc=def,xyz=aaa' => {'abc' => 'def,xyz=aaa'}],
    ['abc="def;xyz";aaa=bbb' => {'abc' => '"def', 'aaa' => 'bbb'}],
  ) {
    my $https = new_https_for_interfaces
        env => {HTTP_COOKIE => $test->[0]};
    for my $http (@$https) {
      my $cookies = $http->request_cookies;
      eq_or_diff $cookies, $test->[1];
      is $http->request_cookies, $cookies;
    }
  }
} # _request_cookies

sub _request_auth : Test(36) {
  for my $test (
    [undef, {}],
    ['' => {}],
    ['Basic' => {}],
    ['Basic abc!xyz' => {}],
    ['Basic abc=', {}],
    ['BASIC abc=', {}],
    ['basic abc=', {}],
    ['basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
     {auth_scheme => 'basic', userid => "Aladdin", password => 'open sesame'}],
    ['Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
     {auth_scheme => 'basic', userid => "Aladdin", password => 'open sesame'}],
    ['BASIC QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
     {auth_scheme => 'basic', userid => "Aladdin", password => 'open sesame'}],
    ['basic QWxhZGRpbjpvcGVuIHNlc2FtZQ',
     {auth_scheme => 'basic', userid => "Aladdin", password => 'open sesame'}],
    ['  basic   QWxhZGRpbjpvcGVuIHNlc2FtZQ',
     {auth_scheme => 'basic', userid => "Aladdin", password => 'open sesame'}],
    ['basic QWxhZGRpbjpvcGVuIHN lc2FtZQ==', {}],
    ['basic YWdlYXdnYXdnYWVmIGFnZXdnZWFmZXdhZ2FnZmV3OmdhZWFnZUpXd2dld2dhZ0d3Z2FnYWVhIGFlZmFnZWVlZWVlZWUgYWdld2dld2FnYXdnYWVld2E=',
     {auth_scheme => 'basic', userid => "ageawgawgaef agewgeafewagagfew",
      password => 'gaeageJWwgewgagGwgagaea aefageeeeeeee agewgewagawgaeewa'}],
    ['Basic aG9nZTrkuIA=' => {auth_scheme => 'basic', userid => 'hoge',
                              password => encode 'utf-8', "\x{4E00}"}],
    ['Basic aG9nZQ==' => {}],
    ['Hoge fuga="" abc', {}],
    ['notbasic QWxhZGRpbjpvcGVuIHNlc2FtZQ', {}],
  ) {
    my $https = new_https_for_interfaces
        env => {HTTP_AUTHORIZATION => $test->[0]};
    for my $http (@$https) {
      eq_or_diff $http->request_auth, $test->[1];
    }
  }
} # _request_auth

sub _request_cache_control : Test(138) {
  for my $test (
    [undef, {}],
    ['', {}],
    ['no-cache', {'no-cache' => undef}, 1],
    ['no-cache=120', {'no-cache' => 120}, 1],
    ['no-store', {'no-store' => undef}],
    ['max-age', {'max-age' => undef}],
    ['max-age=120', {'max-age' => '120'}],
    ['max-age="120"', {'max-age' => '120'}],
    ['max-age=120,max-age=200', {'max-age' => '120,200'}],
    ['max-stale=0', {'max-stale' => '0'}],
    ['max-stale=0,max-stale=2', {'max-stale' => '0,2'}],
    ['Max-Stale=0,max-stale=5', {'max-stale' => '0,5'}],
    ['min-refresh  =  0', {'min-refresh' => '0'}],
    ['NO-transform', {'no-transform' => undef}],
    ['only-if-cached=', {'only-if-cached' => ''}],
    ['  max-stale  =  0    ', {'max-stale' => '0'}],
    ['hoge="fuga,$$1$$,abc"', {'hoge' => 'fuga,$$1$$,abc'}],
    ['hoge=fuga$$1$$abc', {'hoge' => 'fuga$$1$$abc'}],
    ['hoge=fuga,$$1$$,abc', {'hoge' => 'fuga',
                             '$$1$$' => undef, 'abc' => undef}],
    ['hoge=fuga=1', {'hoge' => 'fuga=1'}],
    ['hoge fuga=1', {}],
    ['hoge fuga=1,no-cache', {'no-cache' => undef}, 1],
    [',,max-age=4,,', {'max-age' => 4}],
  ) {
    my $https = new_https_for_interfaces
        env => {HTTP_CACHE_CONTROL => $test->[0]};
    for my $http (@$https) {
      eq_or_diff $http->request_cache_control, $test->[1];
      is $http->request_cache_control, $http->request_cache_control;
      is_bool $http->is_superreload, $test->[2];
    }
  }
} # _request_cache_control

sub _request_ims : Test(8) {
  for my $test (
    [undef, undef],
    ['1224' => undef],
    ['12 Dec 2005 01:12:44 GMT' => 1134349964],
    ['Dec 21 01:12:44 2007' => 1198199564],
  ) {
    my $https = new_https_for_interfaces
        env => {HTTP_IF_MODIFIED_SINCE => $test->[0]};
    for my $http (@$https) {
      is $http->request_ims, $test->[1];
    }
  }
} # _request_ims

# ------ Request body -----

sub _request_body_as_ref_no_body : Test(4) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    is $http->request_body_as_ref, undef;
    is $http->request_body_length, 0;
  }
} # _request_body_as_ref_no_body

sub _request_body_as_ref_with_body : Test(6) {
  my $https = new_https_for_interfaces
      env => {CONTENT_LENGTH => 10},
      request_body => "abc\x40\x9F\xCDaaagewgeeee";
  for my $http (@$https) {
    my $ref = $http->request_body_as_ref;
    is $$ref, "abc\x40\x9F\xCDaaag";
    is $http->request_body_as_ref, $ref;
    is $http->request_body_length, 10;
  }
} # _request_body_as_ref_with_body

sub _request_body_as_ref_with_body_too_short : Test(6) {
  my $https = new_https_for_interfaces
      env => {CONTENT_LENGTH => 100},
      request_body => "abc\x40\x9F\xCDaaagewgeeee";
  for my $http (@$https) {
    dies_here_ok { $http->request_body_as_ref };
    dies_here_ok { $http->request_body_as_ref };
    is $http->request_body_length, 100;
  }
} # _request_body_as_ref_with_body_too_short

sub _request_body_as_ref_zero_body : Test(6) {
  my $https = new_https_for_interfaces
      env => {CONTENT_LENGTH => 0},
      request_body => "";
  for my $http (@$https) {
    my $ref = $http->request_body_as_ref;
    is $$ref, "";
    is $http->request_body_as_ref, $ref;
    is $http->request_body_length, 0;
  }
} # _request_body_as_ref_zero_body

sub _request_body_params_no_body : Test(32) {
  for my $ct (
    undef,
    'application/x-hoge-fuga',
    'application/x-www-form-urlencoded',
    'Application/x-www-FORM-urlencoded',
  ) {
    my $https = new_https_for_interfaces;
    for my $http (@$https) {
      my $params = $http->request_body_params;
      eq_or_diff $params, {};
      is $http->request_body_params, $params;
      
      my $uploads = $http->request_uploads;
      eq_or_diff $uploads, {};
      is $http->request_uploads, $uploads;
    }
  }
} # _request_body_params_no_body

sub _request_body_params_zero_body : Test(32) {
  for my $ct (
    undef,
    'application/x-hoge-fuga',
    'application/x-www-form-urlencoded',
    'Application/x-www-FORM-urlencoded',
  ) {
    my $https = new_https_for_interfaces
        env => {CONTENT_LENGTH => 0, CONTENT_TYPE => $ct},
        request_body => '';
    for my $http (@$https) {
      my $params = $http->request_body_params;
      eq_or_diff $params, {};
      is $http->request_body_params, $params;
      
      my $uploads = $http->request_uploads;
      eq_or_diff $uploads, {};
      is $http->request_uploads, $uploads;
    }
  }
} # _request_body_params_zero_body

sub _request_body_params_zero_with_body_bad_type : Test(16) {
  for my $ct (
    undef,
    'application/x-hoge-fuga',
  ) {
    my $https = new_https_for_interfaces
        env => {CONTENT_LENGTH => 19, CONTENT_TYPE => $ct},
        request_body => 'hogfe=fauga&abc=def';
    for my $http (@$https) {
      my $params = $http->request_body_params;
      eq_or_diff $params, {};
      is $http->request_body_params, $params;
      
      my $uploads = $http->request_uploads;
      eq_or_diff $uploads, {};
      is $http->request_uploads, $uploads;
    }
  }
} # _request_body_params_with_body_bad_type

sub _request_body_params_zero_with_body_with_type : Test(32) {
  for my $ct (
    'application/x-www-form-urlencoded',
    'Application/x-www-form-URLencoded',
    'application/x-www-form-urlencoded; charset=utf-8',
    'application/x-www-form-urlencoded ;charset=utf-8',
  ) {
    my $https = new_https_for_interfaces
        env => {CONTENT_LENGTH => 19, CONTENT_TYPE => $ct},
        request_body => 'hogfe=fauga&abc=def';
    for my $http (@$https) {
      my $params = $http->request_body_params;
      eq_or_diff $params, {hogfe => ['fauga'], abc => ['def']};
      is $http->request_body_params, $params;
      
      my $uploads = $http->request_uploads;
      eq_or_diff $uploads, {};
      is $http->request_uploads, $uploads;
    }
  }
} # _request_body_params_with_body_with_type

sub _request_body_params_form_data : Test(22) {
  my $boundary = 'abc.def';
  my $mime = 'multipart/form-data; boundary=' . $boundary;
  my $data = qq{--$boundary\x0D\x0AContent-Disposition: form-data; name="abcA"\x0D\x0A\x0D\x0AAhgx\xFE\x0D\x0A--$boundary\x0D\x0AContent-Disposition: form-data; name="bsd\xFE\xEC"\x0D\x0A\x0D\x0Azzzzz\x0D\x0A--$boundary\x0D\x0AContent-Disposition: form-data; name="aaaa"; filename="xyz"\x0D\x0A\x0D\x0Aaaabbb\x0D\x0A--$boundary--\x0D\x0A};
  my $https = new_https_for_interfaces
      env => {
        CONTENT_TYPE => $mime,
        CONTENT_LENGTH => length $data,
      },
      request_body => $data;
  for my $http (@$https) {
    my $params = $http->request_body_params;
    eq_or_diff $params, {abcA => ["Ahgx\xFE"],
                         "bsd\xFE\xEC" => ["zzzzz"]};
    is $http->request_body_params, $params;

    my $uploads = $http->request_uploads;
    eq_or_diff [keys %$uploads], ['aaaa'];
    is ref $uploads->{aaaa}, 'ARRAY';
    my $upload = $uploads->{aaaa}->[0];
    isa_ok $upload, 'Wanage::HTTP::MultipartFormData::Upload';
    is $upload->name, 'aaaa';
    is $upload->filename, 'xyz';
    is $upload->size, 6;
    is $upload->as_f->slurp, 'aaabbb';
    is $upload->mime_type->value, undef;
    is $http->request_uploads, $uploads;
  }
} # _request_body_params_form_data

# ------ Response ------

sub _send_response_empty_cgi : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->close_response_body;
  is $out, "Status: 200 OK\n\n";
} # _send_response_empty_cgi

sub _send_response_empty_psgi : Test(2) {
  my $http = Wanage::HTTP->new_from_psgi_env (new_psgi_env);
  dies_here_ok { $http->send_response };
  lives_ok { $http->close_response_body };
} # _send_response_empty_psgi

sub _send_response_empty_psgi_streamable : Test(6) {
  my $http = Wanage::HTTP->new_from_psgi_env
      (new_psgi_env {'psgi.streaming' => 1});
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $http->send_response->(sub { $res = shift; return $writer });
  eq_or_diff $res, undef;
  eq_or_diff $writer->data, [];
  ng $writer->closed;
  $http->close_response_body;
  eq_or_diff $res, [200, []];
  eq_or_diff $writer->data, [];
  ok $writer->closed;
} # _send_response_empty_psgi_streamable

sub _send_response_methods_cgi : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->set_status (402 => "Test\n1");
  $http->set_response_header ('X-Hoge-Fuga' => 123);
  $http->set_response_header ('X_Hoge-Fuga' => "abc def\n\x90");
  $http->add_response_header ('X-Hoge-fuga' => 520);
  $http->set_response_header ("x-Hoge fuga:" => "abc");
  $http->send_response_body_as_ref (\"ab \nxzyz");
  $http->send_response_body_as_ref (\"0");
  eq_or_diff $out, "Status: 402 Test 1
X-Hoge-Fuga: 123
X-Hoge-fuga: 520
X_Hoge-Fuga: abc def \x90
x-Hoge_fuga_: abc

ab\x20
xzyz0";
} # _send_response_methods_cgi

sub _send_response_methods_psgi : Test(1) {
  my $http = Wanage::HTTP->new_from_psgi_env (new_psgi_env);
  $http->set_status (402 => "Test\n1");
  $http->set_response_header ('X-Hoge-Fuga' => 123);
  $http->set_response_header ('X_Hoge-Fuga' => "abc def\n\x90");
  $http->add_response_header ('X-Hoge-fuga' => 520);
  $http->set_response_header ("x-Hoge fuga:" => "abc");
  $http->send_response_body_as_ref (\"ab \nxzyz");
  $http->send_response_body_as_ref (\"0");
  $http->close_response_body;
  eq_or_diff $http->send_response, [402,
                       ['X-Hoge-Fuga' => '123',
                        'X-Hoge-fuga' => '520',
                        'X_Hoge-Fuga' => "abc def \x90",
                        "x-Hoge_fuga_" => 'abc'],
                       ["ab\x20\nxzyz", "0"]];
} # _send_response_methods_psgi

sub _set_status_cgi : Test(6) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->set_status (402 => "Test\n1");
  $http->set_status (103 => "Hoge \x00fuga\x0D");
  ng $http->response_headers_sent;
  $http->send_response_body_as_ref (\"");
  dies_here_ok { $http->set_status (501) };
  eq_or_diff $out, "Status: 103 Hoge \x00fuga \n\n";
  ok $http->response_headers_sent;
} # _set_status_cgi

sub _set_status_default_text_cgi : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->set_status (205);
  $http->send_response_body_as_ref (\"");
  eq_or_diff $out, "Status: 205 Reset Content\n\n";
} # _set_status_default_text_cgi

sub _set_response_header_cgi : Test(4) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->set_response_header ('X-Hoge' => 'ab cd');
  $http->set_response_header ('X-Hoge' => 'xy zz');
  $http->set_response_header ('X-ABC' => '111');
  $http->send_response_body_as_ref (\"");
  dies_here_ok { $http->set_response_header ('X-Hoge' => '1234') };
  eq_or_diff $out, "Status: 200 OK\nX-ABC: 111\nX-Hoge: xy zz\n\n";
} # _set_response_header_cgi

sub _set_response_header_cgi_utf8_name : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  $http->set_response_header ("X-\x{4e00}" => 'ab cd');
  $http->send_response_body_as_ref (\"");
  eq_or_diff $out, "Status: 200 OK\nX-_: ab cd\n\n";
  ng utf8::is_utf8 $out;
} # _set_response_header_cgi_utf8_name

sub _set_response_header_cgi_utf8_name_2 : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  $http->set_response_header ((decode 'utf-8', "X-Hoge") => "ab cd\xFE");
  $http->send_response_body_as_ref (\"");
  eq_or_diff $out, "Status: 200 OK\nX-Hoge: ab cd\xFE\n\n";
  ng utf8::is_utf8 $out;
} # _set_response_header_cgi_utf8_name_2

sub _set_response_header_cgi_utf8_value : Test(3) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  $http->set_response_header ("X-Hoge" => "ab\x{4E00}");
  $http->send_response_body_as_ref (\"");
  eq_or_diff $out, encode 'utf-8', "Status: 200 OK\nX-Hoge: ab\x{4e00}\n\n";
  ng utf8::is_utf8 $out;
} # _set_response_header_cgi_utf8_value

sub _add_response_header_cgi : Test(4) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  ng $http->send_response;
  is $out, '';
  $http->set_response_header ('X-Hoge' => 'zab cd');
  $http->add_response_header ('X-Hoge' => 'xy zz');
  $http->add_response_header ('X-ABC' => ' 111');
  $http->send_response_headers;
  dies_here_ok { $http->add_response_header ('X-Hoge' => '1234') };
  eq_or_diff $out, "Status: 200 OK\nX-ABC:  111\nX-Hoge: zab cd\nX-Hoge: xy zz\n\n";
} # _add_response_header_cgi

sub _send_response_headers_twice : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->send_response_headers;
    dies_here_ok { $http->send_response_headers };
  }
} # _send_response_headers_twice

sub _send_response_body_as_text : Test(1) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response_body_as_text ("\x{4340}abc");
  $http->send_response_body_as_text ("\xAc\xFE\x45\x00ab");
  is $out, "Status: 200 OK\n\n" .
      encode 'utf-8', "\x{4340}abc\xAc\xFE\x45\x00ab";
} # _send_response_body_as_text

sub _send_response_body_as_ref : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->send_response_body_as_ref (\"\xFEabc");
  $http->send_response_body_as_ref (\"\xAc\xFE\x45\x00ab");
  $http->send_response_body_as_ref (\"");
  $http->send_response_body_as_ref (\"0");
  is $out, "Status: 200 OK\n\n\xFEabc\xAc\xFE\x45\x00ab0";
  ok $http->response_headers_sent;
} # _send_response_body_as_ref

sub _close_response_body : Test(8) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  $http->close_response_body;
  dies_here_ok { $http->set_status (201) };
  dies_here_ok { $http->set_response_header (1 => 2) };
  dies_here_ok { $http->add_response_header (3 => 4) };
  dies_here_ok { $http->send_response_headers };
  dies_here_ok { $http->send_response_body_as_ref (\"") };
  dies_here_ok { $http->send_response_body_as_text ("") };
  dies_here_ok { $http->close_response_body };
  ok $http->response_headers_sent;}
 # _close_response_body

sub _send_response_psgi_streamable_multiple : Test(3) {
  my $http = Wanage::HTTP->new_from_psgi_env
      (new_psgi_env {'psgi.streaming' => 1});
  my $writer = Test::Wanage::Envs::PSGI::Writer->new;
  my $res;
  $http->send_response (onready => sub {
    $http->set_status (501);
    $http->add_response_header ('Content-Type' => 'text/plain; charset=utf-8');
    $http->send_response_body_as_text ("\x{1055}");
    $http->send_response_body_as_text ("0");
    $http->close_response_body;
  })->(sub { $res = shift; return $writer });
  eq_or_diff $res, [501, ['Content-Type' => 'text/plain; charset=utf-8']];
  eq_or_diff $writer->data, [(encode 'utf-8', "\x{1055}"), "0"];
  ok $writer->closed;
} # _send_response_empty_psgi_streamable

sub _response_mime_type_empty : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    my $mime = $http->response_mime_type;
    is $mime->value, undef;
    eq_or_diff $mime->params, {};
    is $http->response_mime_type, $mime;
  }
} # _response_mime_type_empty

sub _response_mime_type_has_ct_array : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->{response_headers}->{'content-type'} = [];
    my $mime = $http->response_mime_type;
    is $mime->value, undef;
    eq_or_diff $mime->params, {};
    is $http->response_mime_type, $mime;
  }
} # _response_mime_type_has_ct_array

sub _response_mime_type_has_ct : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('Content-Type' => 'text/css ; charset=utf-8');
    my $mime = $http->response_mime_type;
    is $mime->value, 'text/css';
    eq_or_diff $mime->params, {charset => 'utf-8'};
    is $http->response_mime_type, $mime;
  }
} # _response_mime_type_has_ct

sub _response_mime_type_has_multiple_ct : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('Content-Type' => 'text/css ; charset=utf-8');
    $http->add_response_header ('Content-TYPE' => 'image/svg');
    my $mime = $http->response_mime_type;
    is $mime->value, 'image/svg';
    eq_or_diff $mime->params, {};
    is $http->response_mime_type, $mime;
  }
} # _response_mime_type_has_multiple_ct

sub _response_mime_type_set_value : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->add_response_header ('Content-Type' => 'text/css');
    my $mime = $http->response_mime_type;
    $mime->set_value ('image/svg');
    eq_or_diff $http->{response_headers}->{headers}->{'content-type'},
        [['Content-Type' => 'image/svg']];
  }
} # _response_mime_type_set_value

sub _response_mime_type_set_param : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->add_response_header ('Content-Type' => 'text/css');
    my $mime = $http->response_mime_type;
    $mime->set_param (charset => 'EUC-jp');
    eq_or_diff $http->{response_headers}->{headers}->{'content-type'},
        [['Content-Type' => 'text/css; charset=EUC-jp']];
  }
} # _response_mime_type_set_param

sub _response_mime_type_set_value_invalid : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->add_response_header ('Content-Type' => 'text/css');
    my $mime = $http->response_mime_type;
    $mime->set_value ('image');
    eq_or_diff $http->{response_headers}->{headers}->{'content-type'},
        [['Content-Type' => '']];
  }
} # _response_mime_type_set_value_invalid

sub _response_mime_type_set_value_after_sent : Test(6) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->add_response_header ('Content-Type' => 'text/css');
    $http->send_response_headers;
    my $mime = $http->response_mime_type;
    dies_here_ok {
      $mime->set_value ('image/svg');
    };
    eq_or_diff $http->{response_headers}->{headers}->{'content-type'},
        [['Content-Type' => 'text/css']];
  }
} # _response_mime_type_set_value_after_sent

sub _set_response_cookie : Test(98) {
  for my $test (
    [[], '=; expires=Thu, 01-Jan-1970 00:00:00 GMT'],
    [['hoge' => ''], 'hoge='],
    [['hoge' => 'fuga'], 'hoge=fuga'],
    [['hoge' => '0'], 'hoge=0'],
    [['0' => 'fuga'], '0=fuga'],
    [['' => 'fuga'], '=fuga'],
    [['ho ge=;' => 'fuga;='], 'ho ge__=fuga_='],
    [["ho%FE\xFDge" => "fuga\xCC\x00%01"], "ho%FE\xFDge=fuga\xCC\x00%01"],
    [["hoge\x{6000}" => "fuga\x9C"], "hoge\xe6\x80\x80=fuga\x9C"],
    [["hoge\x9C" => "fuga\x{6000}"], "hoge\x9C=fuga\xe6\x80\x80"],
    [['hoge' => '"fu\"ga"'], 'hoge="fu\"ga"'],
    [['hoge' => 'fuga', expires => 0],
     'hoge=fuga; expires=Thu, 01-Jan-1970 00:00:00 GMT'],
    [['hoge' => 'fuga', expires => 124142],
     'hoge=fuga; expires=Fri, 02-Jan-1970 10:29:02 GMT'],
    [['hoge' => 'fuga', expires => -124142],
     'hoge=fuga; expires=Tue, 30-Dec-1969 13:30:58 GMT'],
    [['hoge' => 'fuga', expires => 1521124142],
     'hoge=fuga; expires=Thu, 15-Mar-2018 14:29:02 GMT'],
    [['hoge' => 'fuga', expires => 3021124142],
     'hoge=fuga; expires=Fri, 25-Sep-2065 17:09:02 GMT'],
    [['hoge' => 'fuga', expires => "abc"],
     'hoge=fuga; expires=Thu, 01-Jan-1970 00:00:00 GMT'],
    [['hoge' => 'fuga', path => undef], 'hoge=fuga'],
    [['hoge' => 'fuga', path => 0], 'hoge=fuga'],
    [['hoge' => 'fuga', path => ''], 'hoge=fuga'],
    [['hoge' => 'fuga', path => '/'], 'hoge=fuga; path=/'],
    [['hoge' => 'fuga', path => '/abc'], 'hoge=fuga; path=/abc'],
    [['hoge' => 'fuga', path => ' / a'], 'hoge=fuga; path= / a'],
    [['hoge' => 'fuga', path => '/a;b'], 'hoge=fuga; path=/a_b'],
    [['hoge' => 'fuga', path => '/a=b'], 'hoge=fuga; path=/a=b'],
    [['hoge' => 'fuga', path => "\xC0"], "hoge=fuga; path=\xC0"],
    [['hoge' => "\xB0fuga", path => "\x{9000}"], "hoge=\xB0fuga; path=\xe9\x80\x80"],
    [['hoge' => 'fuga', domain => undef], 'hoge=fuga'],
    [['hoge' => 'fuga', domain => ''], 'hoge=fuga'],
    [['hoge' => 'fuga', domain => '0'], 'hoge=fuga'],
    [['hoge' => 'fuga', domain => 'hoge.fuga'], 'hoge=fuga; domain=hoge.fuga'],
    [['hoge' => 'fuga', domain => '/a;b'], 'hoge=fuga; domain=/a_b'],
    [['hoge' => 'fuga', domain => '/a=b'], 'hoge=fuga; domain=/a=b'],
    [['hoge' => 'fuga', domain => "\xC0"], "hoge=fuga; domain=\xC0"],
    [['hoge' => "\xB0fuga", domain => "\x{9000}"], "hoge=\xB0fuga; domain=\xe9\x80\x80"],
    [['hoge' => 'fuga', secure => undef], 'hoge=fuga'],
    [['hoge' => 'fuga', secure => ''], 'hoge=fuga'],
    [['hoge' => 'fuga', secure => 0], 'hoge=fuga'],
    [['hoge' => 'fuga', secure => 1], 'hoge=fuga; secure'],
    [['hoge' => 'fuga', httponly => undef], 'hoge=fuga'],
    [['hoge' => 'fuga', httponly => 0], 'hoge=fuga'],
    [['hoge' => 'fuga', httponly => ''], 'hoge=fuga'],
    [['hoge' => 'fuga', httponly => 1], 'hoge=fuga; httponly'],
    [['hoge' => 'fuga', httponly => 'httponly'], 'hoge=fuga; httponly'],
    [['hoge' => 'fuga', abc => 'def'], 'hoge=fuga'],
    [['hoge' => 'fuga', 'max-age' => 0], 'hoge=fuga'],
    [['hoge' => 'fuga', Secure => 1], 'hoge=fuga'],
    [['hoge' => 'fuga', secure => 1, httponly => 1],
     'hoge=fuga; secure; httponly'],
    [["ho\x0Dge" => "fu\x0Aga"], "ho\x0Dge=fu\x0Aga"],
  ) {
    my $https = new_https_for_interfaces;
    for my $http (@$https) {
      $http->set_response_cookie (@{$test->[0]});
      eq_or_diff $http->{response_headers}->{headers}->{'set-cookie'},
          [['Set-Cookie' => $test->[1]]];
    }
  }
} # _set_response_cookie

sub _set_response_cookie_multiple : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('Set-Cookie' => 'abcde');
    $http->set_response_cookie ('hoge' => 'fuga');
    $http->set_response_cookie ('foo' => 'bar');
    $http->set_response_cookie ('foo' => 'bar2');
    eq_or_diff $http->{response_headers}->{headers}->{'set-cookie'},
        [['Set-Cookie' => 'abcde'],
         ['Set-Cookie' => 'hoge=fuga'],
         ['Set-Cookie' => 'foo=bar'],
         ['Set-Cookie' => 'foo=bar2']];
  }
} # _set_response_cookie_multiple

sub _set_response_cookie_after_sent : Test(4) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('Set-Cookie' => 'abcde');
    $http->send_response_headers;
    dies_here_ok {
      $http->set_response_cookie ('hoge' => 'fuga');
    };
    eq_or_diff $http->{response_headers}->{headers}->{'set-cookie'},
        [['Set-Cookie' => 'abcde']];
  }
} # _set_response_cookie_after_sent

sub _set_response_auth : Test(30) {
  for my $test (
    [[], undef],
    [['Basic'], 'Basic realm=""'],
    [['BASIC'], 'Basic realm=""'],
    [['basic'], 'Basic realm=""'],
    [['basic', realm => ''], 'Basic realm=""'],
    [['basic', realm => 'hoge'], 'Basic realm="hoge"'],
    [['Basic', realm => 'hoge'], 'Basic realm="hoge"'],
    [['BASIC', realm => 'hoge'], 'Basic realm="hoge"'],
    [['basic', realm => 'hoge fuga'], 'Basic realm="hoge fuga"'],
    [['basic', realm => 'abc\de'], 'Basic realm="abc_de"'],
    [['basic', realm => 'ab"cd'], 'Basic realm="ab_cd"'],
    [['basic', realm => "\x0D\x0A"], qq{Basic realm="\x0D\x0A"}],
    [['basic', realm => "\x90\xFE"], qq{Basic realm="\xc2\x90\xc3\xbe"}],
    [['basic', realm => "\x{5000}\x{3121}"],
     qq{Basic realm="\xe5\x80\x80\xe3\x84\xa1"}],
  ) {
    my $https = new_https_for_interfaces;
    for my $http (@$https) {
      if (defined $test->[1]) {
        $http->set_response_auth (@{$test->[0]});
        eq_or_diff $http->{response_headers}->{headers}->{'www-authenticate'},
            [['WWW-Authenticate' => $test->[1]]];
      } else {
        dies_here_ok {
          $http->set_response_auth (@{$test->[0]});
        };
        eq_or_diff
            $http->{response_headers}->{headers}->{'www-authenticate'} || [],
            [];
      }
    }
  }
} # _set_response_auth

sub _set_response_auth_multiple : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('WWW-Authenticate' => 'abcde');
    $http->set_response_auth ('basic' => realm => 'fuga');
    $http->set_response_auth ('basic' => realm => 'bar');
    eq_or_diff $http->{response_headers}->{headers}->{'www-authenticate'},
        [['WWW-Authenticate' => 'abcde'],
         ['WWW-Authenticate' => 'Basic realm="fuga"'],
         ['WWW-Authenticate' => 'Basic realm="bar"']];
  }
} # _set_response_auth_multiple

sub _set_response_auth_after_sent : Test(4) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_header ('WWW-Authenticate' => 'abcde');
    $http->send_response_headers;
    dies_here_ok {
      $http->set_response_auth ('basic', realm => 'fuga');
    };
    eq_or_diff $http->{response_headers}->{headers}->{'www-authenticate'},
        [['WWW-Authenticate' => 'abcde']];
  }
} # _set_response_auth_after_sent

sub _set_response_last_modified : Test(20) {
  for my $test (
    [undef, 'Thu, 01 Jan 1970 00:00:00 GMT'],
    [0 =>  'Thu, 01 Jan 1970 00:00:00 GMT'],
    [1 => 'Thu, 01 Jan 1970 00:00:01 GMT'],
    [121414111 => 'Tue, 06 Nov 1973 06:08:31 GMT'],
    [-12222 => 'Wed, 31 Dec 1969 20:36:18 GMT'],
    [1999941222 => 'Tue, 17 May 2033 11:13:42 GMT'],
    [21999942222 => 'Sun, 24 Feb 2667 23:03:42 GMT'],
    ['abc' => 'Thu, 01 Jan 1970 00:00:00 GMT'],
    [2141214512.1211 => 'Sat, 07 Nov 2037 13:48:32 GMT'],
    ["\x{1000}abc" => 'Thu, 01 Jan 1970 00:00:00 GMT'],
  ) {
    my $https = new_https_for_interfaces;
    for my $http (@$https) {
      $http->set_response_last_modified ($test->[0]);
      eq_or_diff $http->{response_headers}->{headers}->{'last-modified'},
          [['Last-Modified' => $test->[1]]];
    }
  }
} # _set_response_last_modified

sub _set_response_last_modified_multiple : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_last_modified (5215212);
    $http->set_response_last_modified (1999941222);
    eq_or_diff $http->{response_headers}->{headers}->{'last-modified'},
        [['Last-Modified' => 'Tue, 17 May 2033 11:13:42 GMT']];
  }
} # _set_response_last_modified_multiple

sub _set_response_last_modified_after_sent : Test(4) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_last_modified (5215212);
    $http->send_response_headers;
    dies_here_ok {
      $http->set_response_last_modified (1999941222);
    };
    eq_or_diff $http->{response_headers}->{headers}->{'last-modified'},
        [['Last-Modified' => 'Mon, 02 Mar 1970 08:40:12 GMT']];
  }
} # _set_response_last_modified_after_sent

sub _set_response_disposition : Test(38) {
  for my $test (
    [[], 'attachment'],
    [[disposition => 'attachment'], 'attachment'],
    [[disposition => 'Attachment'], 'attachment'],
    [[disposition => 'ATTACHMENT'], 'attachment'],
    [[disposition => 'inline'], 'inline'],
    [[disposition => 'InLine'], 'inline'],
    [[disposition => 'INLINE'], 'inline'],
    [[disposition => 'x-hoge-fuga'], 'x-hoge-fuga'],
    [[disposition => "abc<\"&>,\\\";\xFE\xAC"], "abc<_&>____\xFE\xAC"],
    [[disposition => 'in line'], 'in line'],
    [[filename => undef], 'attachment'],
    [[filename => ''], 'attachment; filename=""'],
    [[filename => 'abc'], 'attachment; filename="abc"'],
    [[filename => 'abc.txt'], 'attachment; filename="abc.txt"'],
    [[filename => '/foo/bar'], 'attachment; filename="/foo/bar"'],
    [[filename => 'hoge fuga'], 'attachment; filename="hoge fuga"'],
    [[filename => '"<&>:;\\\''], "attachment; filename=%22%3C%26%3E%3A%3B%5C%27; filename*=utf-8''%22%3C%26%3E%3A%3B%5C%27"],
    [[filename => "\x00\xFFabc"], "attachment; filename=%00%C3%BFabc; filename*=utf-8''%00%C3%BFabc"],
    [[filename => "\x{4e00}\x{FC}\x{1000}"], "attachment; filename=%E4%B8%80%C3%BC%E1%80%80; filename*=utf-8''%E4%B8%80%C3%BC%E1%80%80"],
  ) {
    my $https = new_https_for_interfaces;
    for my $http (@$https) {
      $http->set_response_disposition (@{$test->[0]});
      eq_or_diff $http->{response_headers}->{headers}->{'content-disposition'},
          [['Content-Disposition' => $test->[1]]];
    }
  }
} # _set_response_disposition

sub _set_response_disposition_multiple : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_disposition (disposition => 'inline');
    $http->set_response_disposition (disposition => 'x-hoge',
                                     filename => 'abc.txt');
    eq_or_diff $http->{response_headers}->{headers}->{'content-disposition'},
        [['Content-Disposition' => 'x-hoge; filename="abc.txt"']];
  }
} # _set_response_disposition_multiple

sub _set_response_disposition_sent : Test(4) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    $http->set_response_disposition (disposition => 'inline');
    $http->send_response_headers;
    dies_here_ok {
      $http->set_response_disposition (disposition => 'x-hoge',
                                       filename => 'abc.txt');
    };
    eq_or_diff $http->{response_headers}->{headers}->{'content-disposition'},
        [['Content-Disposition' => 'inline']];
  }
} # _set_response_disposition_sent

sub _onclose : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    my $invoked;
    $http->onclose (sub { $invoked = 1 });
    $http->send_response_headers;
    undef $http;
    ok $invoked;
  }
} # _onclose

sub _onclose_no_response : Test(2) {
  my $https = new_https_for_interfaces;
  for my $http (@$https) {
    my $invoked;
    $http->onclose (sub { $invoked = 1 });
    undef $http;
    ng $invoked;
  }
} # _onclose_no_response

__PACKAGE__->runtests;

$Wanage::HTTP::DetectLeak = 1;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
