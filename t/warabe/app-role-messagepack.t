package test::Warabe::App::Role::MessagePack;
use strict;
BEGIN {
  my $file_name = __FILE__;
  $file_name =~ s{[^/]+$}{};
  $file_name ||= '.';
  $file_name .= '/../../config/perl/libs.txt';
  if (-f $file_name) {
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, scalar <$file>;
  }
}
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Wanage::Envs;
use Wanage::HTTP;
use Data::MessagePack;
use MIME::Base64 qw(encode_base64url);

{
  package test::Warabe::App::Role::MessagePack::App::MessagePack;
  use Warabe::App::Role::MessagePack;
  use Warabe::App;
  push our @ISA, qw(Warabe::App::Role::MessagePack Warabe::App);
}

our $APP_CLASS = 'test::Warabe::App::Role::MessagePack::App::MessagePack';

sub _version : Test(1) {
  ok $Warabe::App::Role::MessagePack::VERSION;
} # _version

sub _mp_param : Test(6) {
  for (
    [undef, undef, undef, undef],
    ['json=1241', undef, undef, undef],
    ['json=' . (Data::MessagePack->encode ("abc")), undef, undef, 'abc'],
    ['json=' . (Data::MessagePack->encode ({"abc\x{FE}\x{CD}\x{4E00}" => 124})), undef, undef, {"abc\xc3\xbe\xc3\x8d\xe4\xb8\x80" => 124}],
    ['json=' . (Data::MessagePack->encode ('391')),
     'application/x-www-form-urlencoded',
     'json=' . (Data::MessagePack->encode ('124')), 391],
    [undef, 'application/x-www-form-urlencoded',
     'json=' . (Data::MessagePack->encode ('xyz')), 'xyz'],
  ) {
    my $in = $_->[2];
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      QUERY_STRING => $_->[0],
      CONTENT_TYPE => $_->[1],
      CONTENT_LENGTH => defined $in ? length $in : 0,
    }, $in;
    my $app = $APP_CLASS->new_from_http ($http);
    my $json = $app->mp_param ('json');
    eq_or_diff $json, $_->[3];
  }
}

sub _mpb64_param : Test(7) {
  for (
    [undef, undef, undef, undef],
    ['json=1241', undef, undef, undef],
    ['json=' . encode_base64url (Data::MessagePack->encode ("abc")), undef, undef, 'abc'],
    ['json=' . encode_base64url (Data::MessagePack->encode ({"abc\x{FE}\x{CD}\x{4E00}" => 124})), undef, undef, {"abc\xc3\xbe\xc3\x8d\xe4\xb8\x80" => 124}],
    ['json=' . encode_base64url (Data::MessagePack->encode ('391')),
     'application/x-www-form-urlencoded',
     'json=' . encode_base64url (Data::MessagePack->encode ('124')), 391],
    [undef, 'application/x-www-form-urlencoded',
     'json=' . encode_base64url (Data::MessagePack->encode ('xyz')), 'xyz'],
    ['json=' . (Data::MessagePack->encode ({"abc\x{FE}\x{CD}\x{4E00}" => 124})), undef, undef, undef],
  ) {
    my $in = $_->[2];
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      QUERY_STRING => $_->[0],
      CONTENT_TYPE => $_->[1],
      CONTENT_LENGTH => defined $in ? length $in : 0,
    }, $in;
    my $app = $APP_CLASS->new_from_http ($http);
    my $json = $app->mpb64_param ('json');
    eq_or_diff $json, $_->[3];
  }
}

sub _send_mp : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_mp ({"\x{4000}ab" => [123, "xyxz"]});
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/x-msgpack

@{[Data::MessagePack->new->encode({"\xe4\x80\x80ab"=>[123,"xyxz"]})]}};
} # _send_mp

sub _send_mp_undef : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_mp (undef);
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/x-msgpack

@{[Data::MessagePack->new->encode(undef)]}};
} # _send_mp_undef

sub _send_mp_scalar : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_mp ("abcd\x{4000}");
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/x-msgpack

@{[Data::MessagePack->new->encode("abcd\xe4\x80\x80")]}};
} # _set_response_mp_scalar

sub _send_mp_binary : Test(2) {
  my $out = '';
  my $http = with_cgi_env { Wanage::HTTP->new_cgi } {}, undef, $out;
  my $app = $APP_CLASS->new_from_http ($http);
  $app->send_mp ("abcd\xFE\x89\xDC\xED");
  dies_here_ok {
    $http->send_response_body_as_ref (\'abcde');
  };
  eq_or_diff $out, qq{Status: 200 OK
Content-Type: application/x-msgpack

@{[Data::MessagePack->new->encode("abcd\xFE\x89\xDC\xED")]}};
} # _set_response_mp_scalar

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
