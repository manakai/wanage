package Wanage::Interface::CGI;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Encode;
use IO::Handle;
use Wanage::Interface::Base;
push our @ISA, qw(Wanage::Interface::Base);

# ------ Constructor ------

sub new_from_main ($) {
  return bless {
    env => \%ENV,
    request_body_handle => *STDIN{IO},
    response_handle => *STDOUT{IO},
  }, $_[0];
} # new_from_main

# ------ Request data ------

sub url_scheme ($) {
  return $_[0]->{url_scheme} ||= (
    (($_[0]->{env}->{HTTPS} || '') =~ /^(?:[Oo][Nn]|1)$/) ? 'https' : 'http'
  );
} # url_scheme

sub get_meta_variable ($$) {
  return $_[0]->{env}->{$_[1]};
} # get_meta_variable

sub get_request_body_as_ref ($) {
  my $length = $_[0]->{env}->{CONTENT_LENGTH};
  return undef unless defined $length;
  croak "Request body has already been read" if $_[0]->{request_body_read};
  my $buf = '';
  $_[0]->{request_body_handle}->read ($buf, $length);
  croak "CGI error: premature end of input"
      unless $length == length $buf;
  $_[0]->{request_body_read} = 1;
  return \$buf;
} # get_request_body_as_ref

# ------ Response ------

sub set_status ($$;$) {
  croak "You can no longer set status" if $_[0]->{response_headers_sent};
  $_[0]->{status} = $_[1];
  $_[0]->{status_text} = $_[2];
} # set_status

sub set_response_headers ($$) {
  croak "You can no longer set response headers"
      if $_[0]->{response_headers_sent};
  $_[0]->{response_headers} = $_[1];
} # set_response_headers

sub send_response_headers ($) {
  croak "You can no longer send data" if $_[0]->{done};
  return if $_[0]->{response_headers_sent};
  my $handle = $_[0]->{response_handle};

  my $status = ($_[0]->{status} || 200) + 0;
  my $status_text = $_[0]->{status_text};
  $status_text = do {
    require Wanage::HTTP::Info;
    $Wanage::HTTP::Info::ReasonPhrases->{$status} || '';
  } unless defined $status_text;
  $status_text =~ s/\s+/ /g;

  print $handle "Status: $status $status_text\n";
  my $has_ct_or_location;
  for (@{$_[0]->{response_headers} or []}) {
    my $name = $_->[0];
    $has_ct_or_location = 1 if $name =~ /\A(?:Content-Type|Location)\z/i;
    my $value = $_->[1];
    $name =~ s/[^0-9A-Za-z_-]/_/g; ## Far more restrictive than RFC 3875
    $value =~ s/[\x0D\x0A]+[\x09\x20]*/ /g;
    print $handle "$name: $value\n";
  }
  unless ($has_ct_or_location) {
    print $handle "Content-Type: text/plain; charset=utf-8\n";
  }
  print $handle "\n";
  
  $_[0]->{response_headers_sent} = 1;
} # send_response_headers

sub send_response_body ($;$) {
  $_[0]->send_response_headers;
  
  my $writer = $_[0]->{writer} ||= bless {handle => $_[0]->{response_handle}},
      'Wanage::Interface::CGI::Writer';
  $_[1]->($writer);
} # send_response_body

sub done ($) {
  $_[0]->send_response_headers;
  $_[0]->{writer}->close if $_[0]->{writer};
  $_[0]->{done} = 1;
} # done

package Wanage::Interface::CGI::Writer;
our $VERSION = '1.0';
use Carp;

sub print ($$) {
  $_[0]->{handle}->print ($_[1]) or croak $!;
} # write

sub close ($$) {
  $_[0]->{handle}->close or croak $!;
} # close

sub DESTROY {
  $_[0]->close;
} # DESTROY

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
