package Wanage::URL;
use strict;
use warnings;
our $VERSION = '1.0';
require utf8;
use Exporter::Lite;
use Encode;
use Web::URL::Canonicalize qw(
  parse_url resolve_url canonicalize_parsed_url serialize_parsed_url
);

## ------ URL object ------

sub new_from_string ($$) {
  return bless parse_url ($_[1]), ref $_[0] ? ref $_[0] : $_[0];
} # new_from_string

sub new_from_parsed_url ($$) {
  return bless $_[1], ref $_[0] ? ref $_[0] : $_[0];
} # new_from_parsed_url

our $AboutBlank = bless {
  scheme => 'about',
  scheme_normalized => 'about',
  path => 'blank',
}, __PACKAGE__;

sub get_canon_url ($) {
  return $_[0]->new_from_parsed_url (canonicalize_parsed_url resolve_url serialize_parsed_url $_[0], $AboutBlank);
} # get_canon_url

sub resolve_string ($$) {
  # $_[0] must be a canon URL
  return $_[0]->new_from_parsed_url (resolve_url $_[1], $_[0]);
} # resolve_string

sub set_scheme ($$) {
  $_[0]->{scheme} = $_[1];
  $_[0]->{scheme_normalized} = $_[1];
} # set_scheme

# $_[0] must be canonicalized
sub ascii_origin ($) {
  return undef unless defined $_[0]->{scheme};
  return undef unless defined $_[0]->{host};
  return $_[0]->{scheme} . '://' . $_[0]->{host}
      . (defined $_[0]->{port} ? ':' . $_[0]->{port} : '');
} # ascii_origin

sub clone ($) {
  return bless {%{$_[0]}}, ref $_[0];
} # clone

sub stringify ($) {
  return serialize_parsed_url $_[0]; # or undef
} # stringify

## ------ Percent encode functions ------

## Original: <https://github.com/wakaba/perl-web-utils/blob/master/lib/URL/PercentEncode.pm>.

our @EXPORT = qw(
  percent_encode_b
  percent_encode_c
  percent_decode_b
  percent_decode_c
  parse_form_urlencoded_b
);

sub percent_encode_b ($) {
  my $s = ''.$_[0];
  $s =~ s/([^0-9A-Za-z._~-])/sprintf '%%%02X', ord $1/ge;
  utf8::encode ($s);
  return $s;
} # percent_encode_b

sub percent_encode_c ($) {
  my $s = Encode::encode ('utf-8', ''.$_[0]);
  $s =~ s/([^0-9A-Za-z._~-])/sprintf '%%%02X', ord $1/ge;
  return $s;
} # percent_encode_c

sub percent_decode_b ($) {
  my $s = ''.$_[0];
  utf8::encode ($s) if utf8::is_utf8 ($s);
  $s =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
  return $s;
} # percent_decode_b

sub percent_decode_c ($) {
  my $s = ''.$_[0];
  utf8::encode ($s) if utf8::is_utf8 ($s);
  $s =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
  return Encode::decode ('utf-8', $s);
} # percent_decode_c

sub parse_form_urlencoded_b ($) {
  if (not defined $_[0]) {
    return {};
  } else {
    my $params = {};
    for (split /[&;]/, $_[0], -1) {
      my ($n, $v) = map { defined $_ ? do {
        my $v = $_; $v =~ tr/+/ /; percent_decode_b $v;
      } : '' } split /[=]/, $_, 2;
      push @{$params->{defined $n ? $n : ''} ||= []}, defined $v ? $v : '';
    }
    return $params;
  }
} # parse_form_urlencoded_b

1;

=head1 LICENSE

Copyright 2010-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
