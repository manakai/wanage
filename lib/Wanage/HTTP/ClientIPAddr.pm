package Wanage::HTTP::ClientIPAddr;
use strict;
use warnings;
our $VERSION = '1.0';
use List::Ish;
use Web::IPAddr::Canonicalize qw(
  canonicalize_ipv6_addr
  canonicalize_ipv4_addr
);

## See:
## <http://suika.fam.cx/~wakaba/wiki/sw/n/REMOTE_ADDR>
## <http://suika.fam.cx/~wakaba/wiki/sw/n/X-Forwarded-For>

sub new_from_interface ($$) {
  my ($class, $if) = @_;
  my $addrs = List::Ish->new ([grep { $_ } map {
    if ($_ and /:/) {
      canonicalize_ipv6_addr $_;
    } else {
      canonicalize_ipv4_addr $_;
    }
    ## "unknown" value is ignored.
  } (
     $if->get_meta_variable ('REMOTE_ADDR'),
     map { s/\A[\x09\x0A\x0D\x20]+//; s/[\x09\x0A\x0D\x20]+\z//; $_ }
     split /,/, $if->get_request_header ('X-Forwarded-For') || ''
  )]);
  return bless {addrs => $addrs}, $class;
} # new_from_interface

sub select_addr ($) {
  return $_[0]->{selected_addr} ||= $_[0]->{addrs}->[-1];
} # select_addr

sub as_text ($) {
  return $_[0]->select_addr;
} # as_text

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
