package test::Wanage::URL;
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

sub _version : Test(1) {
  ok $Wanage::URL::VERSION;
} # _version

sub _new_from_string : Test(3) {
  my $url = Wanage::URL->new_from_string (q<htTp://Foo.bar?bar#baz>);
  isa_ok $url, 'Wanage::URL';
  is $url->get_canon_url->stringify, q<http://foo.bar/?bar#baz>;
  is $url->stringify, q<htTp://Foo.bar?bar#baz>;
} # _new_from_string

sub _new_from_parsed_url : Test(3) {
  my $parsed_url = {scheme => 'httP', scheme_normalized => 'http',
                    is_hierarchical => 1, path => q</hoge>};
  my $url = Wanage::URL->new_from_parsed_url ($parsed_url);
  is $url, $parsed_url;
  isa_ok $url, 'Wanage::URL';
  is $url->stringify, q<httP:/hoge>;
} # new_from_parsed_url

sub _about_blank : Test(2) {
  isa_ok $Wanage::URL::AboutBlank, 'Wanage::URL';
  is $Wanage::URL::AboutBlank->stringify, 'about:blank';
} # _about_blank

sub _get_canon_url : Test(3) {
  my $url = Wanage::URL->new_from_string (qq<httP://hoge:80/fuga/../.??\x99>);
  my $url2 = $url->get_canon_url;
  isa_ok $url2, 'Wanage::URL';
  is $url2->stringify, q<http://hoge/??%C2%99>;
  is $url->stringify, qq<httP://hoge:80/fuga/../.??\x99>;
} # _get_canon_url

sub _resolve_string : Test(3) {
  my $url = Wanage::URL->new_from_string (q<https://hoge.fuga/ab/cd/ef>);
  my $url2 = $url->resolve_string (q<barzcxds>);
  isa_ok $url2, 'Wanage::URL';
  is $url2->stringify, q<https://hoge.fuga/ab/cd/barzcxds>;
  is $url->stringify, q<https://hoge.fuga/ab/cd/ef>;
} # resolve_string

sub _set_scheme : Test(3) {
  my $url = Wanage::URL->new_from_string (q<https://hoge.fuga/ab/cd/ef>);
  $url->set_scheme ('about');
  is $url->stringify, q<about://hoge.fuga/ab/cd/ef>;
  is $url->{scheme_normalized}, 'about';
  is $url->{scheme}, 'about';
} # _set_scheme

sub _ascii_origin : Test(10) {
  for (
    [q<https://hoge.fuga/ab/cd/ef> => q<https://hoge.fuga>],
    [q<HTTP://hoge.fuga/ab/cd/ef> => q<http://hoge.fuga>],
    [q<https://hoge.fuga:0145/ab/cd/ef> => q<https://hoge.fuga:145>],
    [q<http://hoge.fuga:80/ab/cd/ef> => q<http://hoge.fuga>],
    [qq<http://hoge.\x{5e00}fuga/ab/cd/ef> => q<http://hoge.xn--fuga-py1h>],
    [q<https:hoge.fuga/ab/cd/ef> => undef],
    [q<about://hoge.fuga/ab/cd/ef> => undef],
    [q<hoge://hoge.fuga/ab/cd/ef> => q<hoge://hoge.fuga>],
    [q<https://hoge.fuga:80/ab/cd/ef> => q<https://hoge.fuga:80>],
    [q<//hoge.fuga/ab/cd/ef> => undef],
  ) {
    my $url = Wanage::URL->new_from_string ($_->[0])->get_canon_url;
    is $url->ascii_origin, $_->[1];
  }
} # _ascii_origin

sub _clone : Test(5) {
  my $url = Wanage::URL->new_from_string (q<https://hoge.fuga/ab/cd/ef>);
  my $url2 = $url->clone;
  isnt $url2, $url;
  isa_ok $url2, 'Wanage::URL';
  is $url2->stringify, $url->stringify;
  is $url2->{scheme_normalized}, 'https';
  ok $url2->{is_hierarchical};
} # _clone

sub _stringify : Test(2) {
  my $url = Wanage::URL->new_from_string (q<http://ho>);
  is ref $url->stringify, '';
  is $url->stringify, q<http://ho>;
} # _stringify

sub _stringify_invalid : Test(2) {
  my $url = Wanage::URL->new_from_string (q<hthoge>);
  is ref $url->stringify, '';
  is $url->stringify, undef;
} # _stringify_invalid

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
