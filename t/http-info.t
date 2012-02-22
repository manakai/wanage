package test::Wanage::HTTP::Info;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use Wanage::HTTP::Info;
use base qw(Test::Class);
use Test::More;

sub _version : Test(1) {
  ok $Wanage::HTTP::Info::VERSION;
} # _version

sub _reason_phrases : Tests {
  for my $status (keys %$Wanage::HTTP::Info::ReasonPhrases) {
    ok defined $Wanage::HTTP::Info::ReasonPhrases->{$status};
  }
} # _reason_phrases

sub _idempotent_methods : Tests {
  for my $method (keys %$Wanage::HTTP::Info::IdempotentMethods) {
    ok $Wanage::HTTP::Info::IdempotentMethods->{$method};
  }
  ok $Wanage::HTTP::Info::IdempotentMethods->{GET};
  ok $Wanage::HTTP::Info::IdempotentMethods->{HEAD};
  ok $Wanage::HTTP::Info::IdempotentMethods->{PUT};
  ok !$Wanage::HTTP::Info::IdempotentMethods->{POST};
} # _idempotent_methods

sub _safe_methods : Tests {
  for my $method (keys %$Wanage::HTTP::Info::SafeMethods) {
    ok $Wanage::HTTP::Info::SafeMethods->{$method};
  }
  ok $Wanage::HTTP::Info::SafeMethods->{GET};
  ok $Wanage::HTTP::Info::SafeMethods->{HEAD};
  ok !$Wanage::HTTP::Info::SafeMethods->{PUT};
  ok !$Wanage::HTTP::Info::SafeMethods->{POST};
} # _safe_methods

sub _case_insensitive_methods : Tests {
  for my $method (keys %$Wanage::HTTP::Info::CaseInsensitiveMethods) {
    ok $Wanage::HTTP::Info::CaseInsensitiveMethods->{$method};
  }
  ok $Wanage::HTTP::Info::CaseInsensitiveMethods->{GET};
  ok $Wanage::HTTP::Info::CaseInsensitiveMethods->{HEAD};
  ok !$Wanage::HTTP::Info::CaseInsensitiveMethods->{SEARCH};
  ok !$Wanage::HTTP::Info::CaseInsensitiveMethods->{MKCOL};
} # _case_insensitive_methods

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
