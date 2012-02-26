#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->parent->subdir ('modules', 'manakai', 'lib')->stringify;
use Data::Dumper;
use Whatpm::HTTP::_StatusCodes;
use Whatpm::HTTP::_Methods;

my $ReasonPhrases = {};

for my $code (keys %$Whatpm::HTTP::StatusCodes) {
  my $def = $Whatpm::HTTP::StatusCodes->{$code};
  if (defined $def->{text}) {
    $ReasonPhrases->{$code} = $def->{text};
  }
}

my $IdempotentMethods = {};
my $SafeMethods = {};
my $CaseInsensitiveMethods = {};

for my $method (keys %$Whatpm::HTTP::Methods) { 
  my $def = $Whatpm::HTTP::Methods->{$method};
  $IdempotentMethods->{$method} = 1 if $def->{idempotent};
  $SafeMethods->{$method} = 1 if $def->{safe};
  $CaseInsensitiveMethods->{$method} = 1 if $def->{case_insensitive};
}

$Data::Dumper::Sortkeys = 1;

my $now = [gmtime];
printf qq{package Wanage::HTTP::Info;\n\$VERSION = %f;\n},
    $Whatpm::HTTP::_StatusCodes::VERSION +
    $Whatpm::HTTP::_Methods::VERSION;

print map { s/^\$VAR1/\$ReasonPhrases/; $_ } Dumper $ReasonPhrases;
print map { s/^\$VAR1/\$IdempotentMethods/; $_ } Dumper $IdempotentMethods;
print map { s/^\$VAR1/\$SafeMethods/; $_ } Dumper $SafeMethods;
print map { s/^\$VAR1/\$CaseInsensitiveMethods/; $_ } Dumper $CaseInsensitiveMethods;

print qq{1;};

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
