package Wanage::URL;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::URL::Canonicalize qw(
  parse_url resolve_url canonicalize_parsed_url serialize_parsed_url
);

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

sub stringify ($) {
  return serialize_parsed_url $_[0]; # or undef
} # stringify

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
