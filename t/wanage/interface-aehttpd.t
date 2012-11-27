use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::MoreMore;
use Test::Wanage::Envs;
use AnyEvent::HTTPD;
use Wanage::Interface::AnyEventHTTPD;
use Web::UserAgent::Functions qw(http_get http_post_data);

test {
  my $c = shift;
  ok $Wanage::Interface::AnyEventHTTPD::VERSION;
  done $c;
} n => 1, name => 'version';

test {
  my $c = shift;

  my $port = 1024 + int rand 10000;
  my $httpd = AnyEvent::HTTPD->new (port => $port);

  my $req_url;
  $httpd->reg_cb
      (request => sub {
         my ($httpd, $req) = @_;
         my $if = Wanage::Interface::AnyEventHTTPD->new_from_httpd_and_req ($httpd, $req);
         $req_url = $if->get_meta_variable ('REQUEST_URI');

         $if->send_response_headers
             (status => 203,
              status_text => 'Hoge',
              headers => [
                  ['Content-Type', 'text/html'],
              ]);
         $if->send_response (onready => sub {
             $if->send_response_body ("hoge");
             $if->close_response_body;
         });
     });

  my $timer; $timer = AE::timer 0.2, 0, sub {
      test {
          http_get
              url => qq<http://localhost:$port/hoge?fuga>,
              anyevent => 1,
              cb => sub {
                  my (undef, $res) = @_;
                  test {
                      is $req_url, q</hoge?fuga>;
                      is $res->header('Content-Type'), 'text/html';
                      is $res->code, 203;
                      is $res->message, 'Hoge';
                      is $res->content, 'hoge';
                      
                      done $c;
                      undef $c;
                      undef $httpd;
                  } $c;
              };
      } $c;
      undef $timer;
  };
} n => 5;

test {
  my $c = shift;

  my $port = 1024 + int rand 10000;
  my $httpd = AnyEvent::HTTPD->new (port => $port);

  my $invoked;
  my $req_url;
  $httpd->reg_cb
      (request => sub {
         my ($httpd, $req) = @_;
         my $if = Wanage::Interface::AnyEventHTTPD->new_from_httpd_and_req ($httpd, $req);
         $req_url = $if->get_meta_variable ('REQUEST_URI');

         $if->send_response_headers
             (status => 203,
              status_text => 'Hoge',
              headers => [
                  ['Content-Type', 'text/html'],
              ]);
         $if->onclose (sub { $invoked = 1 });
         $if->send_response (onready => sub {
             $if->send_response_body ("hoge");
             $if->close_response_body;
         });
     });

  my $timer; $timer = AE::timer 0.2, 0, sub {
      test {
          http_get
              url => qq<http://localhost:$port/hoge?fuga>,
              anyevent => 1,
              cb => sub {
                  my (undef, $res) = @_;
                  test {
                      ok $invoked;
                      
                      done $c;
                      undef $c;
                      undef $httpd;
                  } $c;
              };
      } $c;
      undef $timer;
  };
} n => 1, name => 'with onclose';

test {
  my $c = shift;

  my $port = 1024 + int rand 10000;
  my $httpd = AnyEvent::HTTPD->new (port => $port);

  my $invoked;
  my $req_url;
  $httpd->reg_cb
      (request => sub {
         my ($httpd, $req) = @_;
         my $if = Wanage::Interface::AnyEventHTTPD->new_from_httpd_and_req ($httpd, $req);
         $req_url = $if->get_meta_variable ('REQUEST_URI');

         $if->send_response_headers
             (status => 203,
              status_text => 'Hoge',
              headers => [
                  ['Content-Type', 'text/html'],
              ]);
         $if->onclose (sub { $invoked = 1 });
         $if->send_response_body ("hoge");
         $if->send_response;
     });

  my $timer; $timer = AE::timer 0.2, 0, sub {
      test {
          http_get
              url => qq<http://localhost:$port/hoge?fuga>,
              anyevent => 1,
              cb => sub {
                  my (undef, $res) = @_;
                  test {
                      ok $invoked;
                      
                      done $c;
                      undef $c;
                      undef $httpd;
                  } $c;
              };
      } $c;
      undef $timer;
  };
} n => 1, name => 'with onclose';

run_tests;

=head1 LICENSE

Copyright 2012 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
