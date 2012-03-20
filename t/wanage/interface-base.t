package test::Wanage::Interface::CGI;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Wanage::Interface::Base;
use Test::MoreMore;

sub _version : Test(1) {
  ok $Wanage::Interface::Base::VERSION;
} # _version

## There are more tests in |interface-cgi.t|.

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
