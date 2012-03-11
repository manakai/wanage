package Wanage::HTTP::Date;
use strict;
use warnings;
our $VERSION = '1.0';
use Time::Local qw(timegm);
use Exporter::Lite;

our @EXPORT = qw(parse_http_date);

## RFC 6265 Section 5.1.1. with a bug fix: "(non-digit *OCTET)" in
## grammer can be omitted.
sub parse_http_date ($) {
  ## Step 1.
  my @token = split /([\x09\x20-\x2F\x3B-\x40\x5B-\x60\x7B-\x7E])/, $_[0], -1;
  
  ## Step 2.
  my $hour_value;
  my $minute_value;
  my $second_value;
  my $day_of_month_value;
  my $month_value;
  my $year_value;
  for my $token (@token) {
    ## Step 2.1.
    if (not defined $hour_value and
        $token =~ /\A([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})(?:[^0-9].*|)\z/s) {
      $hour_value = $1;
      $minute_value = $2;
      $second_value = $3;
      next;
    }

    ## Step 2.2.
    if (not defined $day_of_month_value and 
        $token =~ /\A([0-9]{1,2})(?:[^0-9].*|)\z/s) {
      $day_of_month_value = $1;
      next;
    }
    
    ## Step 2.3.
    if (not defined $month_value and
        $token =~ /\A([Jj][Aa][Nn]|[Ff][Ee][Bb]|[Mm][Aa][Rr]|[Aa][Pp][Rr]|[Mm][Aa][Yy]|[Jj][Uu][Nn]|[Jj][Uu][Ll]|[Aa][Uu][Gg]|[Ss][Ee][Pp]|[Oo][Cc][Tt]|[Nn][Oo][Vv]|[Dd][Ee][Cc]).*\z/s) {
      $month_value = {qw(jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7
                         aug 8 sep 9 oct 10 nov 11 dec 12)}->{lc $1};
      next;
    }

    if (not defined $year_value and
        $token =~ /\A([0-9]{2,4})(?:[^0-9].*|)\z/s) {
      $year_value = $1;
      next;
    }
  }

  ## Step 5.
  return undef if 
      not defined $day_of_month_value or
      not defined $month_value or
      not defined $year_value or
      not defined $hour_value;

  ## Step 3.
  if ($year_value >= 70 and $year_value <= 99) {
    $year_value += 1900;
  }

  ## Step 4.
  if ($year_value >= 0 and $year_value <= 69) {
    $year_value += 2000;
  }

  ## Step 5.
  return undef if $year_value < 1601;
  return undef if $hour_value > 23;
  return undef if $minute_value > 59;
  return undef if $second_value > 59;

  ## Step 6., Step 7.
  local $@;
  return scalar eval {
    timegm $second_value, $minute_value, $hour_value,
        $day_of_month_value, $month_value - 1, $year_value;
  }; # or undef
} # parse_http_date

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
