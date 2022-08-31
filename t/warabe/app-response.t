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
    $app->send_error (204);
  });
  is $out, q{Status: 204 No Content
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => '204';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_error (204, reason_phrase => 'Foo Nar');
  });
  is $out, q{Status: 204 Foo Nar
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => 'reason 204';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_error (304);
  });
  is $out, q{Status: 304 Not Modified
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => '304';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_error (304, reason_phrase => 'Foo Nar');
  });
  is $out, q{Status: 304 Foo Nar
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => 'reason 304';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
    REQUEST_METHOD => 'HEAD',
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_error (201);
  });
  is $out, q{Status: 201 Created
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => 'HEAD';

test {
  my $c = shift;
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
    SERVER_NAME => 'hoge.fuga',
    SERVER_PORT => 80,
    REQUEST_METHOD => 'HEAD',
  }, undef, $out;
  my $app = Warabe::App->new_from_http ($http);
  $app->execute (sub {
    $app->send_error (202, reason_phrase => 'Foo Nar');
  });
  is $out, q{Status: 202 Foo Nar
Content-Type: text/plain; charset=us-ascii

};
  done $c;
} n => 1, name => 'reason HEAD';

run_tests;

$Warabe::App::DetectLeak = 1;

=head1 LICENSE

Copyright 2012-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
