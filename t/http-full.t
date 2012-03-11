package test::Wanage::HTTP::Full;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Wanage::HTTP::Full;

sub _version : Test(1) {
  ok $Wanage::HTTP::Full::VERSION;
} # _version

sub _classes : Test(2) {
  ok +Wanage::HTTP::Full->isa ('Wanage::HTTP');
  ok +Wanage::HTTP::Full->isa ('Wanage::HTTP::Role::JSON');
} # _classes

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
