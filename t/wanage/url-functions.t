package test::Wanage::URL::functions;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Wanage::URL;
use Test::MoreMore;

sub _flagged ($) {
  my $v = "\x{4e00}" . $_[0];
  return substr $v, 1;
} # _flagged

sub _pe : Test(32) {
  for (
      [undef, '', ''],
      ['' => '', ''],
      ['abc' => 'abc', 'abc'],
      [_flagged 'abc' => 'abc', 'abc'],
      ["\xA1\xC8\x4E\x4B\x21\x0D" => '%A1%C8NK%21%0D', '%C2%A1%C3%88NK%21%0D'],
      ["http://abc/a+b?x(y)z~[*]" => 'http%3A%2F%2Fabc%2Fa%2Bb%3Fx%28y%29z~%5B%2A%5D', 'http%3A%2F%2Fabc%2Fa%2Bb%3Fx%28y%29z%7E%5B%2A%5D'],
      ["\x{4e00}\xC1" => '%4E00%C1', '%E4%B8%80%C3%81'],
      ["ab+cd" => 'ab%2Bcd', 'ab%2Bcd'],
  ) {
    my $s = percent_encode_b ($_->[0]);
    is $s, $_->[1];
    ok !utf8::is_utf8 ($s);

    my $t = percent_encode_c ($_->[0]);
    is $t, $_->[2];
    ok !utf8::is_utf8 ($s);
  }
} # _pe

sub _pd : Test(39) {
  for (
      [undef, '', ''],
      ['', '', ''],
      ['abc', 'abc', 'abc'],
      [_flagged 'abc', 'abc', 'abc'],
      ['%A1%C8NK%21%0D', "\xA1\xC8NK!\x0D", "\x{FFFD}\x{FFFD}NK!\x0D"],
      ['%C2%A1%C3%88NK%21%0D', "\xC2\xA1\xC3\x88NK!\x0D", "\xA1\xC8NK!\x0D"],
      ['http%3A%2F%2Fabc%2Fa%2Bb%3Fx%28y%29z~%5B%2A%5D', 'http://abc/a+b?x(y)z~[*]', 'http://abc/a+b?x(y)z~[*]'],
      ["\xA1\xC8\x4E\x4B\x21\x0D", "\xA1\xC8NK!\x0D", "\x{FFFD}\x{FFFD}NK!\x0D"],
      ["\x{4e00}\xC1", "\xE4\xB8\x80\xC3\x81", "\x{4e00}\xC1"],
      ['%4E00%C1', "\x4e00\xC1", "\x4e00\x{FFFD}"],
      ['%E4%B8%80%C3%81', "\xE4\xB8\x80\xC3\x81", "\x{4e00}\xC1"],
      [_flagged '%E4%B8%80%C3%81', "\xE4\xB8\x80\xC3\x81", "\x{4e00}\xC1"],
      ['ab+cd', 'ab+cd', 'ab+cd'],
  ) {
    no warnings 'uninitialized';

    my $s = percent_decode_b ($_->[0]);
    is $s, $_->[1], join '/', '_pd', 'b', $_->[0];
    ok !utf8::is_utf8 ($s);

    my $t = percent_decode_c ($_->[0]);
    is $t, $_->[2], join '/', '_pd', 'c', $_->[0];
  }
} # _pd

sub _parse_form_urlencoded_b : Test(26) {
  for (
    [undef, {}],
    ['', {}],
    ['0' => {0 => ['']}],
    ['ab=cd' => {ab => ['cd']}],
    ['ab=cd&ab=ef' => {ab => ['cd', 'ef']}],
    ['ab=ef&ab=cd' => {ab => ['ef', 'cd']}],
    ['ab=cd&ab=cd' => {ab => ['cd', 'cd']}],
    ['ab=cd&AB=ef' => {ab => ['cd'], AB => ['ef']}],
    ['ab=cd&xy=ef' => {ab => ['cd'], xy => ['ef']}],
    ['ab=cd;ab=ef' => {ab => ['cd', 'ef']}],
    ['a%19%87%AC%feb=cd%43%9E%21' => {"a\x19\x87\xAC\xFEb" => ["cd\x43\x9E\x21"]}],
    ['ab=cc&0' => {ab => ['cc'], 0 => ['']}],
    ['ab=cc&0=' => {ab => ['cc'], 0 => ['']}],
    ['ab=cc&=0' => {ab => ['cc'], '' => ['0']}],
    ['ab=cc=0' => {ab => ['cc=0']}],
    ['=ab=' => {'' => ['ab=']}],
    ['ab=cc%260' => {ab => ['cc&0']}],
    ['ab=cc&' => {ab => ['cc'], '' => ['']}],
    ['&ab=cc&' => {ab => ['cc'], '' => ['', '']}],
    ['&&' => {'' => ['', '', '']}],
    ['&;&' => {'' => ['', '', '', '']}],
    ['&%3B&' => {'' => ['', ''], ';' => ['']}],
    ["\x{5000}\x{200}%CD=\x{5000}%26%9E" => {"\xe5\x80\x80\xc8\x80\xcd" => ["\xe5\x80\x80&\x9e"]}],
    ["\xFE\xA9\xCE=\x81\x40" => {"\xFE\xA9\xCE" => ["\x81\x40"]}],
    ['ab+cd=xy+zb' => {'ab cd' => ['xy zb']}],
    ['ab+%2Bcd+=xy+%2bzb+' => {'ab +cd ' => ['xy +zb ']}],
  ) {
    eq_or_diff parse_form_urlencoded_b $_->[0], $_->[1];
  }
} # parse_form_urlencoded_b

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2010-2018 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
