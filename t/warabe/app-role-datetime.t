package test::Warabe::App::Role::DateTime;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Wanage::Envs;
use Encode;
use Wanage::HTTP;

{
  package test::Warabe::App::Role::DateTime::App::DateTime;
  use base qw(Warabe::App::Role::DateTime Warabe::App);
}

our $APP_CLASS = 'test::Warabe::App::Role::DateTime::App::DateTime';

sub _version : Test(1) {
  ok $Warabe::App::Role::DateTime::VERSION;
} # _version

sub _epoch_param_as_datetime : Test(13) {
  for my $test (
    ['', undef],
    ['hoge=' => undef],
    ['hoge=0' => '1970-01-01T00:00:00'],
    ['hoge=5215222' => '1970-03-02T08:40:22'],
    ['hoge=-5215222' => '1969-11-01T15:19:38'],
    ['hoge=21315215222' => '2645-06-14T21:07:02'],
    ['hoge=214212315215222' => undef],
    ['hoge=2422214212315215222' => undef],
    ['hoge=242221abcde' => undef],
    ['hoge=+242221333' => undef],
    ['hoge=xyz%20242221abcde' => undef],
    ['hoge=21315215222&hoge=124422' => '2645-06-14T21:07:02'],
    ['hoge=21a315215222&hoge=124422' => undef],
  ) {
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      QUERY_STRING => $test->[0],
    };
    my $app = $APP_CLASS->new_from_http ($http);
    my $dt = $app->epoch_param_as_datetime ('hoge');
    if ($test->[1]) {
      is_datetime $dt, $test->[1];
    } else {
      is $dt, undef;
    }
  }
} # _epoch_param_as_datetime

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
