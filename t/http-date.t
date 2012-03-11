package test::Wanage::HTTP::Date;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use Wanage::HTTP::Date;
use base qw(Test::Class);
use Test::More;
use Time::Local qw(timegm);
use JSON::Functions::XS qw(file2perl json_bytes2perl);

sub _version : Test(1) {
  ok $Wanage::HTTP::Date::VERSION;
} # _version

sub _parse_date : Test(28) {
  for (
    [undef, undef],
    ['' => undef],
    ['0' => undef],
    ['14221222' => undef],
    ['-1' => undef],
    ['Mon, 02 Feb 2004 12:42:11 GMT' => [2004,2,2,12,42,11]],
    ['hox, 02 mar 2004 12:42:11 +0900' => [2004,3,2,12,42,11]],
    ['12 OCT 04 12:42:11' => [2004,10,12,12,42,11]],
    ['12:42:11 2012 dec 10' => [2012,12,10,12,42,11]],
    ['  12:42:11 2012 ;;dec   10,  ' => [2012,12,10,12,42,11]],
    ['12 : 42 : 11 2012 dec 10' => undef],
    ['2012-04-01T12:42:11' => undef],
    ['19 november 11 02:02:01' => [2011,11,19,2,2,1]],
    ['19 november 91 02:02:01' => [1991,11,19,2,2,1]],
    ['19 november 70 02:02:01' => [1970,11,19,2,2,1]],
    ['19 november 69 02:02:01' => [2069,11,19,2,2,1]],
    ['19 november 1660 02:02:01' => [1660,11,19,2,2,1]],
    ['19 november 1659 02:02:01' => [1659,11,19,2,2,1]],
    ['19 november 2059 02:02:01' => [2059,11,19,2,2,1]],
    ['19 november 2059 02:02:01abc' => [2059,11,19,2,2,1]],
    ['19 november 1091 02:02:01' => undef],
    ['190 november 1991 02:02:01' => undef],
    ['19xx novabc 69aa 02:02:01def' => [2069,11,19,2,2,1]],
    ['Mon, 02-Feb-2004 12:42:11 GMT' => [2004,2,2,12,42,11]],
    ['Sun, 06 Nov 1994 08:49:37 GMT' => [1994,11,6,8,49,37]],
    ['Sunday, 06-Nov-94 08:49:37 GMT' => [1994,11,6,8,49,37]],
    ['Sun Nov 6 08:49:37 1994' => [1994,11,6,8,49,37]],
    ['Sun Nov  6 08:49:37 1994' => [1994,11,6,8,49,37]],
  ) {
    my $result = parse_date $_->[0];
    is $result, $_->[1]
        ? timegm @{(map { $_->[4]--; $_ } [reverse @{$_->[1]}])[0]} : undef;
  }
} # _parse_date

my $data_d = file (__FILE__)->dir->subdir ('data');

sub _examples : Tests {
  my $json = file2perl $data_d->file ('http-state-dates', 'examples.json');
  for (@$json) {
    my $input = $_->{test};
    my $expected = $_->{expected};
    $expected = parse_date $expected if $expected;
    is parse_date $input, $expected;
  }
} # _examples

sub _bsd_examples : Tests {
  my $data = $data_d->file ('http-state-dates', 'bsd-examples.json')->slurp;
  $data =~ s{//.*}{}g;
  my $json = json_bytes2perl $data;
  for (@$json) {
    my $input = $_->{test};
    my $expected = $_->{expected};
    $expected = parse_date $expected if $expected;
    is parse_date $input, $expected;
  }
} # _bsd_examples

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
