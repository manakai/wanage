package Wanage::Interface::AnyEventHTTPD;
use strict;
use warnings;
our $VERSION = '1.0';
require utf8;
use Carp;
use Encode;
use IO::Handle;
use Scalar::Util qw(weaken);
use Wanage::Interface::Base;
push our @ISA, qw(Wanage::Interface::Base);

## ------ Constructor ------

sub new_from_httpd_and_req ($) {
  return bless {
    httpd => $_[1],
    req => $_[2],
  }, $_[0];
} # new_from_httpd_and_req

## ------ Request data ------

sub url_scheme ($) {
  return $_[0]->{url_scheme} ||= (
    $_[0]->_url_scheme_by_proxy ||
    $_[0]->{httpd}->{ssl} ? 'https' : 'http',
  );
  ## Though AnyEvent::HTTPD support |ssl| option, whether the request
  ## is accessed with TLS or not cannot be detected from the request
  ## object.
} # url_scheme

sub get_meta_variable ($$) {
  if ($_[1] =~ /\AHTTP_([0-9A-Z_]+)\z/) {
    my $header = $1;
    $header =~ tr/A-Z_/a-z-/;
    return $_[0]->{req}->headers->{$header};
  } elsif ($_[1] eq 'CONTENT_TYPE') {
    return $_[0]->{req}->headers->{'content-type'};
  } elsif ($_[1] eq 'REQUEST_URI') {
    return '' . $_[0]->{req}->url;
  } elsif ($_[1] eq 'REQUEST_METHOD') {
    return $_[0]->{req}->method;
  } elsif ($_[1] eq 'SERVER_NAME') {
    return $_[0]->{httpd}->host;
  } elsif ($_[1] eq 'SERVER_PORT') {
    return $_[0]->{httpd}->port;
  } elsif ($_[1] eq 'REMOTE_ADDR') {
    return $_[0]->{req}->client_host;
  } elsif ($_[1] eq 'REMOTE_PORT') {
    return $_[0]->{req}->client_port;
  } elsif ($_[1] eq 'CONTENT_LENGTH') {
    if (defined $_[0]->{req}->content) {
      return length $_[0]->{req}->content;
    } else {
      return undef;
    }
  } else {
    return undef;
  }
} # get_meta_variable

## AnyEvent::HTTPD does not return content if the request is GET or if
## the request MIME type is one of form-data MIME types.

sub get_request_body_as_ref ($) {
  croak "Request body has already been read" if $_[0]->{request_body_read};
  $_[0]->{request_body_read} = 1;
  return undef unless defined $_[0]->{req}->content;
  return \($_[0]->{req}->content);
} # get_request_body_as_ref

sub get_request_body_as_handle ($) {
  croak "Request body has already been read" if $_[0]->{request_body_read};
  $_[0]->{request_body_read} = 1;
  return undef unless defined $_[0]->{req}->content;
  open my $data, \($_[0]->{req}->content);
  return $data;
} # get_request_body_as_handle

## ------ Response ------

sub set_response_headers ($$) {
  croak "You can no longer set response headers"
      if $_[0]->{response_headers_sent};
  $_[0]->{response_headers} = $_[1];
} # set_response_headers

sub send_response_headers ($;%) {
  my ($self, %args) = @_;
  croak "Response body is already closed" if $self->{response_body_closed};
  if ($self->{response_headers_sent}) {
    if (defined $args{status} or
        defined $args{status_text} or
        $args{headers}) {
      croak "You can no longer set response headers";
    }
    return;
  }
  my $handle = $self->{response_handle};

  my $status = $args{status};
  $status = 200 if not defined $status;
  $status = 0 + $status;
  my $status_text = $args{status_text};
  $status_text = do {
    require Wanage::HTTP::Info;
    $Wanage::HTTP::Info::ReasonPhrases->{$status} || '';
  } unless defined $status_text;
  $status_text =~ s/\s+/ /g;
  $status_text = encode 'utf-8', $status_text if utf8::is_utf8 ($status_text);

  my $headers = {};
  for (@{$args{headers} or []}) {
    my $name = $_->[0];
    my $value = $_->[1];
    $name =~ s/[^0-9A-Za-z_-]/_/g; ## Far more restrictive than RFC 3875
    $value =~ s/[\x0D\x0A]+[\x09\x20]*/ /g;
    $name = encode 'utf-8', $name if utf8::is_utf8 ($name);
    $value = encode 'utf-8', $value if utf8::is_utf8 ($value);
    if (defined $headers->{$name}) {
      $headers->{$name} .= ',' . $value;
    } else {
      $headers->{$name} = $value;
    }
  }
  $self->{response} = [$status, $status_text, $headers, sub {
    my $writer = $_[0] or do {
      delete $self->{response_buffer};
      return;
    };
    if (@{$self->{response_buffer} or []}) {
      $writer->(join '', map { $$_ } @{(delete $self->{response_buffer}) or []});
    } elsif ($self->{response_body_closed}) {
      $writer->(undef);
    } else {
      $self->{response_writer} = $writer;
    }
  }];
  if ($self->{response_sent}) {
    $self->{req}->respond($self->{response});
    delete $self->{response};
  }
  
  $self->{response_headers_sent} = 1;
} # send_response_headers

sub send_response_body ($$) {
  my $self = $_[0];
  croak "Response body is already closed" if $self->{response_body_closed};
  $self->send_response_headers;
  next unless length $_[1];
  if ($self->{response_writer}) {
    (delete $self->{response_writer})
        ->(join '', @{(delete $self->{response_buffer}) or []}, $_[1]);
  } else {
    push @{$self->{response_buffer} ||= []}, \($_[1]);
  }
} # send_response_body

sub close_response_body ($) {
  my $self = shift;
  croak "Response body is already closed" if $self->{response_body_closed};
  $self->send_response_headers;
  if ($self->{response_writer}) {
    (delete $self->{response_writer})->(undef);
  }
  $self->{response_body_closed} = 1;
} # close_response_body

sub send_response ($;%) {
  my ($self, %args) = @_;
  my $code = $args{onready};
  croak "Response has already been sent" if $self->{response_sent};
  $self->{response_sent} = 1;
  $code->() if $code;
  if ($self->{response_headers_sent}) {
    $self->{req}->respond($self->{response});
    delete $self->{response};
  }
  return;
} # send_response

sub DESTROY {
  my $self = shift;
  if ($self->{response_sent} and not $self->{response_headers_sent}) {
    warn "Response is discarded before it is sent\n";
  }
} # DESTROY

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
