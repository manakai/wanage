package Wanage::HTTP::Full;
use strict;
use warnings;
our $VERSION = '1.0';
use Wanage::HTTP;
use Wanage::HTTP::Role::JSON;
push our @ISA, qw(
  Wanage::HTTP
  Wanage::HTTP::Role::JSON
);

1;
