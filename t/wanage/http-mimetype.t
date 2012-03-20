package test::Wanage::HTTP::MIMEType;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Wanage::HTTP::MIMEType;
use Encode;
require utf8;

sub _version : Test(1) {
  ok $Wanage::HTTP::MIMEType::VERSION;
} # _version

sub _new_from_content_type : Test(58) {
  for (
    [undef, [undef, {}]],
    ['' => [undef, {}]],
    ['text/html' => ['text/html', {}]],
    ['Text/HTML' => ['text/html', {}]],
    ['  text/html  ' => ['text/html', {}]],
    ['text / html' => [undef, {}]],
    ['text/html+' => ['text/html+', {}]],
    ['text/html/' => [undef, {}]],
    ['text/html;hoge' => ['text/html', {}]],
    ['text/html;charset=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;charset="utf-8"' => ['text/html', {charset => 'utf-8'}]],
    ['text/html  ; charset  =  utf-8  ' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;CharsET=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;charset=UTF-8' => ['text/html', {charset => 'UTF-8'}]],
    ['text/html;charset=utf-8;charset=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;text/plain;charset=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;charset utf-8' => ['text/html', {}]],
    ['text/html;charset=utf-8;version=3' => ['text/html', {charset => 'utf-8', version => 3}]],
    ['text/html;0=0' => ['text/html', {0 => '0'}]],
    ['0/0;charset=utf-8' => ['0/0', {charset => 'utf-8'}]],
    ['0;charset=utf-8' => [undef, {}]],
    ['text/html;charset="utf-8;hoge=abc"' => ['text/html', {charset => 'utf-8;hoge=abc'}]],
    ['application/xhtml+XML;charset=utf-8' => ['application/xhtml+xml', {charset => 'utf-8'}]],
    ['text/html;charset=utf-8,text/plain' => ['text/plain', {}]],
    ['text/html;charset=utf-8,' => [undef, {}]],
    ['text/html;charset=utf-8,hoge' => [undef, {}]],
    [',text/html;charset=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/plain, ,  text/html;charset=utf-8' => ['text/html', {charset => 'utf-8'}]],
    ['text/html;charset=utf-8;desc="a,b,c"' => ['text/html', {charset => 'utf-8', desc => 'a,b,c'}]],
  ) {
    my $mime = Wanage::HTTP::MIMEType->new_from_content_type ($_->[0]);
    isa_ok $mime, 'Wanage::HTTP::MIMEType';
    eq_or_diff [$mime->value, $mime->params], $_->[1];
  }
} # _new_from_content_type

sub _is_type : Test(26) {
  for (
    {in => undef},
    {in => ''},
    {in => 'text/html', html => 1},
    {in => 'text/html; charset=us-ascii', html => 1},
    {in => 'application/xhtml+xml', xml => 1},
    {in => 'application/xml', xml => 1},
    {in => 'text/xml', xml => 1},
    {in => 'application/xslt+xml', xml => 1},
    {in => 'image/svg+xml', xml => 1},
    {in => 'text/xsl'},
    {in => 'text/plain'},
    {in => 'text/css'},
    {in => 'application/xml-dtd'},
  ) {
    my $mime = Wanage::HTTP::MIMEType->new_from_content_type ($_->{in});
    is_bool $mime->is_html_mime_type, $_->{html};
    is_bool $mime->is_xml_mime_type, $_->{xml};
  }
} # is_type

sub _setters : Test(2) {
  my $mime = Wanage::HTTP::MIMEType->new_from_content_type;
  $mime->set_value ('Text/HTML');
  is $mime->value, 'text/html';
  $mime->set_param (Charset => 'US-ASCII');
  is $mime->params->{charset}, 'US-ASCII';
} # _setters

sub _as_bytes : Test(7) {
  local $Wanage::HTTP::MIMEType::Sortkeys = 1;
  for (
    [undef, undef],
    ['' => undef],
    ['text/html' => 'text/html'],
    ['text/plain;charset=us-ascii' => 'text/plain; charset=us-ascii'],
    ['text/html;charset=us-ascii;version=2.0' => 'text/html; charset=us-ascii; version=2.0'],
    ['video/mpeg;codec="hoge,fuga,abc;def"' => 'video/mpeg; codec="hoge,fuga,abc;def"'],
    ['application/xhtml+xml' => 'application/xhtml+xml'],
  ) {
    my $mime = Wanage::HTTP::MIMEType->new_from_content_type ($_->[0]);
    is $mime->as_bytes, $_->[1];
  }
} # _as_bytes

sub _as_bytes_flagged : Test(2) {
  local $Wanage::HTTP::MIMEType::Sortkeys = 1;
  my $mime = Wanage::HTTP::MIMEType->new_from_content_type;
  $mime->{value} = decode 'utf-8', 'text/plain';
  $mime->params->{"\x{5000}"} = "hoge";
  $mime->params->{"abc"} = "\x{F0}";
  $mime->params->{hoge} = 'xyz';
  $mime->params->{hoge2} = decode 'utf-8', 'xyz';
  is $mime->as_bytes, 'text/plain; hoge=xyz; hoge2=xyz';
  ng utf8::is_utf8 ($mime->as_bytes);
} # _as_bytes_flagged

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
