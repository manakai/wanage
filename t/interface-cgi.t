package test::Wanage::Interface::CGI;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Wanage::Interface::CGI;
use Test::MoreMore;

sub with_cgi_env (&;$$$) {
  my ($code, $env, $stdin_data, $stdout_data) = @_;
  local %ENV = %{$env or {}};
  local *STDIN;
  local *STDOUT;
  open STDIN, '<', \($_[2]) if defined $stdin_data;
  open STDOUT, '>', \($_[3]) if defined $stdout_data;
  return $code->();
} # with_cgi_env

sub _version : Test(2) {
  ok $Wanage::Interface::CGI::VERSION;
  ok $Wanage::Interface::CGI::Writer::VERSION;
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
  is $cgi->original_url->stringify, 'http://:';
  is $cgi->canon_url->stringify, 'http:///';
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

sub _original_url_from_request_uri_abs_non_http : Test(4) {
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
} # _original_url_from_request_uri_abs_non_http

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
    $cgi->set_status (400, $input);
    $cgi->send_response_headers;
    eq_or_diff $out, qq{Status: 400 $expected\nContent-Type: text/plain; charset=utf-8\n\n};
  }
} # _set_status

sub _set_status_twice : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->set_status (400);
  $cgi->set_status (402);
  $cgi->send_response_headers;
  dies_here_ok { $cgi->set_status (404) };
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 402 Payment Required\nContent-Type: text/plain; charset=utf-8\n\n};
} # _set_status_twice

sub _set_response_headers : Test(8) {
  for (
    [[] => qq{Content-Type: text/plain; charset=utf-8\n}],
    [[['Title' => 'HOge Fuga']] => qq{Title: HOge Fuga\nContent-Type: text/plain; charset=utf-8\n}],
    [[['Title' => 'HOge Fuga'], [Title => "\x{500}\x{2000}a"]] => qq{Title: HOge Fuga\nTitle: \xd4\x80\xe2\x80\x80a\nContent-Type: text/plain; charset=utf-8\n}],
    [[['Content-Type' => 'text/html; charset=euc-jp']] => qq{Content-Type: text/html; charset=euc-jp\n}],
    [[['Hoge' => "Fu\x0D\x0Aga"]] => qq{Hoge: Fu ga\nContent-Type: text/plain; charset=utf-8\n}],
    [[["Hoge\x00\x0A" => "Fu\x0D\x0Aga"]] => qq{Hoge__: Fu ga\nContent-Type: text/plain; charset=utf-8\n}],
    [[["Hog\x{1000}" => "Fu\x0D\x0Aga"]] => qq{Hog_: Fu ga\nContent-Type: text/plain; charset=utf-8\n}],
    [[['Content-TYPE' => '']] => qq{Content-TYPE: \n}],
  ) {
    my ($input, $expected) = @$_;
    my $out = '';
    my $cgi = with_cgi_env {
      Wanage::Interface::CGI->new_from_main;
    } {}, undef, $out;
    $cgi->set_response_headers ($input);
    $cgi->send_response_headers;
    eq_or_diff $out, qq{Status: 200 OK\n$expected\n};
  }
} # _set_response_headers

sub _set_response_headers_twice : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->set_response_headers ([['Hoge' => 'Fuga']]);
  $cgi->set_response_headers ([['Hoge' => 'Hoe']]);
  $cgi->send_response_headers;
  dies_here_ok { $cgi->set_response_headers ([['Hoge' => 'Abc']]) };
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 200 OK\nHoge: Hoe\nContent-Type: text/plain; charset=utf-8\n\n};
} # _set_response_headers_twice

sub _send_response_headers_empty : Test(1) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\n};
} # _send_response_headers_empty

sub _send_response_body : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  isa_ok $writer, 'Wanage::Interface::CGI::Writer';
  $writer->print ("Hello, ");
  $writer->print ("World.");
  $writer->close;
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\nHello, World.};
} # _send_response_body

sub _send_response_body_no_close : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  isa_ok $writer, 'Wanage::Interface::CGI::Writer';
  $writer->print ("Hello, ");
  $writer->print ("World.");
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\nHello, World.};
} # _send_response_body_no_close

sub _send_response_body_print_after_close : Test(4) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  isa_ok $writer, 'Wanage::Interface::CGI::Writer';
  $writer->print ("Hello, ");
  $writer->close;
  dies_here_ok {
    $writer->print ("World.");
  };
  dies_here_ok {
    $writer->close;
  };
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\nHello, };
} # _send_response_body_no_close

sub _send_response_body_twice : Test(3) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  my $writer2;
  $cgi->send_response_body (sub {
    $writer2 = $_[0];
  });
  isa_ok $writer, 'Wanage::Interface::CGI::Writer';
  is $writer2, $writer;
  $writer->print ("Hello, ");
  $writer2->print ("World.");
  $writer->close;
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\nHello, World.};
} # _send_response_body_twice

sub _send_response_body_header : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  $cgi->send_response_headers;
  isa_ok $writer, 'Wanage::Interface::CGI::Writer';
  $writer->print ("Hello, ");
  $writer->print ("World.");
  $writer->close; 
  $cgi->send_response_headers;
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\nHello, World.};
} # _send_response_body_header

sub _done_send_response_headers : Test(2) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main
  } {}, undef, $out;
  my $writer;
  $cgi->done;
  dies_here_ok {
    $cgi->send_response_headers;
  };
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\n};
} # _done_send_response_body

sub _done_send_response_body : Test(3) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->done;
  dies_here_ok {
    $cgi->send_response_body (sub {
      $writer = $_[0];
    });
  };
  ng $writer;
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\n};
} # _done_send_response_body

sub _done_send_response_body_writer : Test(3) {
  my $out = '';
  my $cgi = with_cgi_env {
    Wanage::Interface::CGI->new_from_main;
  } {}, undef, $out;
  my $writer;
  $cgi->send_response_body (sub {
    $writer = $_[0];
  });
  $cgi->done;
  dies_here_ok {
    $writer->print ("abc");
  };
  eq_or_diff $out, qq{Status: 200 OK\nContent-Type: text/plain; charset=utf-8\n\n};
} # _done_send_response_body_writer

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
