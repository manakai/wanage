package Wanage::HTTP;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Encode;
use URL::PercentEncode qw(parse_form_urlencoded_b);

our @CARP_NOT = qw(Wanage::Interface::CGI Wanage::Interface::PSGI);

# ------ Constructor ------

sub new_cgi ($) {
  require Wanage::Interface::CGI;
  return bless {
    interface => Wanage::Interface::CGI->new_from_main,
  }, $_[0];
} # new_cgi

sub new_from_psgi_env ($$) {
  require Wanage::Interface::PSGI;
  return bless {
    interface => Wanage::Interface::PSGI->new_from_psgi_env ($_[1]),
  }, $_[0];
} # new_from_psgi_env

# ------ Request data ------

# ---- Request URL ----

sub url ($) {
  return $_[0]->{interface}->canon_url;
} # url

sub original_url ($) {
  return $_[0]->{interface}->original_url;
} # original_url

sub query_params ($) {
  return $_[0]->{query_params} ||= do {
    parse_form_urlencoded_b
        $_[0]->{interface}->get_meta_variable ('QUERY_STRING');
  };
} # query_params

# ---- Request method ----

sub request_method ($) {
  return $_[0]->{request_method} ||= do {
    my $rm = $_[0]->{interface}->get_meta_variable ('REQUEST_METHOD');
    my $rm_uc = $rm;
    if ($rm_uc =~ tr/a-z/A-Z/) {
      require Wanage::HTTP::Info;
      if ($Wanage::HTTP::Info::CaseInsensitiveMethods->{$rm_uc}) {
        $rm_uc;
      } else {
        $rm;
      }
    } else {
      $rm;
    }
  };
} # request_method

sub request_method_is_safe ($) {
  require Wanage::HTTP::Info;
  return $Wanage::HTTP::Info::SafeMethods->{$_[0]->request_method};
} # request_method_is_safe

sub request_method_is_idempotent ($) {
  require Wanage::HTTP::Info;
  return $Wanage::HTTP::Info::IdempotentMethods->{$_[0]->request_method};
} # request_method_is_idempotent

# ---- Request headers ----

sub get_request_header {
  return $_[0]->{interface}->get_request_header ($_[1]);
} # get_request_header

# ---- Request body ----

sub request_body_as_ref {
  return $_[0]->{request_body_as_ref}
      ||= $_[0]->{interface}->get_request_body_as_ref;
} # request_body_as_ref

sub request_body_params ($) {
  return $_[0]->{request_body_params} ||= do {
    my $ct = [split /;/, $_[0]->get_request_header ('Content-Type') || '', 2]->[0] || '';
    $ct =~ s/[\x09\x0A\x0D\x20]+\z//;
    $ct =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($ct eq 'application/x-www-form-urlencoded') {
      parse_form_urlencoded_b ${$_[0]->request_body_as_ref || \''};
    } elsif ($ct eq 'multipart/form-data') {
      # XXX
      {};
    } else {
      {};
    }
  };
} # request_body_params

# ------ Response construction ------

sub set_status ($$;$) {
  croak "You can no longer set the status" if $_[0]->{response_headers_sent};
  $_[0]->{response_headers}->{status} = $_[1];
  $_[0]->{response_headers}->{status_text} = $_[2];
} # set_status

sub add_response_header ($$$) {
  croak "You can no longer set a header" if $_[0]->{response_headers_sent};
  my ($self, $name, $value) = @_;
  my $i_name = $name;
  $i_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  push @{$self->{response_headers}->{headers}->{$i_name} ||= []},
      [$name => $value];
} # add_response_header

sub set_response_header ($$$) {
  croak "You can no longer set a header" if $_[0]->{response_headers_sent};
  my ($self, $name, $value) = @_;
  my $i_name = $name;
  $i_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{response_headers}->{headers}->{$i_name}
      = [[$name => $value]];
} # set_response_header

our $Sortkeys;

sub send_response_headers ($) {
  my $headers = $_[0]->{response_headers};
  my @headers = values %{$headers->{headers} or {}};
  @headers = sort { $a->[0]->[0] cmp $b->[0]->[0] } @headers if $Sortkeys;
  $_[0]->{interface}->send_response_headers
      (status => $headers->{status},
       status_text => $headers->{status_text},
       headers => [map { @$_ } @headers]);
  $_[0]->{response_headers_sent} = 1;
} # send_response_headers

sub send_response_body_as_text ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->send_response_body (encode 'utf-8', $_[1]);
} # send_response_body_as_text

sub send_response_body_as_ref ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->send_response_body (${$_[1]});
} # send_response_body_as_ref

sub close_response_body ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->close_response_body;
} # close_response_body

sub send_response ($;%) {
  return shift->{interface}->send_response (@_);
} # send_response

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
