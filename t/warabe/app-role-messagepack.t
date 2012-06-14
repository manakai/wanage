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

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
