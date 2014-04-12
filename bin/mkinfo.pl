use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use JSON::Functions::XS qw(json_bytes2perl);
use Data::Dumper;

my $StatusCodes = json_bytes2perl path (__FILE__)->parent->parent->child ('local/http-status-codes.json')->slurp;
my $Methods = json_bytes2perl path (__FILE__)->parent->parent->child ('local/http-methods.json')->slurp;

my $ReasonPhrases = {};

for my $code (keys %$StatusCodes) {
  my $def = $StatusCodes->{$code};
  if (defined $def->{reason}) {
    $ReasonPhrases->{$code} = $def->{reason}
        if defined $def->{protocols}->{HTTP} or
           defined $def->{protocols}->{HTCPCP};
  }
}

my $IdempotentMethods = {};
my $SafeMethods = {};
my $CaseInsensitiveMethods = {};

for my $method (keys %$Methods) { 
  my $def = $Methods->{$method};
  $IdempotentMethods->{$method} = 1 if $def->{idempotent};
  $SafeMethods->{$method} = 1 if $def->{safe};
  $CaseInsensitiveMethods->{$method} = 1 if $def->{case_insensitive};
}

$Data::Dumper::Sortkeys = 1;

print qq{package Wanage::HTTP::Info;\n\$VERSION = '40271348.0';\n};
print map { s/^\$VAR1/\$ReasonPhrases/; $_ } Dumper $ReasonPhrases;
print map { s/^\$VAR1/\$IdempotentMethods/; $_ } Dumper $IdempotentMethods;
print map { s/^\$VAR1/\$SafeMethods/; $_ } Dumper $SafeMethods;
print map { s/^\$VAR1/\$CaseInsensitiveMethods/; $_ } Dumper $CaseInsensitiveMethods;
print qq{1;};

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
