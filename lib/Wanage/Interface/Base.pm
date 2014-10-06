package Wanage::Interface::Base;
use strict;
use warnings;
our $VERSION = '1.0';
use Encode;
use Wanage::URL;

# ------ Request message ------

sub get_meta_variable { die "meta_variable not implemented" }

sub get_request_header ($$) {
  my $name = $_[1];
  $name = '' unless defined $name;
  $name =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
  if ($name eq 'CONTENT-TYPE') {
    ## This might not be a real HTTP header field, according to CGI
    ## spec, but in fact it is in the real world.
    return $_[0]->get_meta_variable ('CONTENT_TYPE');
  } elsif ($name eq 'CONTENT-LENGTH') {
    ## Strictly speaking, there might not be the |Content-Length|
    ## request header field, in fact.
    return $_[0]->get_meta_variable ('CONTENT_LENGTH');
  } else {
    ## This might not be available depending on the interface;
    ## according to the CGI spec the server does not have to provide
    ## all header fields.
    return undef if $name =~ /_/;
    $name =~ tr/-/_/;
    return $_[0]->get_meta_variable ('HTTP_' . $name);
  }
} # get_request_header

# ------ Request URL ------

sub url_scheme { die "url_scheme not implemented" }

sub _url_scheme_by_proxy {
  if ($Wanage::HTTP::UseCFVisitor) {
    ## <https://support.cloudflare.com/hc/en-us/articles/200170536-How-do-I-redirect-HTTPS-traffic-with-Flexible-SSL-and-Apache->
    my $scheme = $_[0]->get_request_header ('CF-Visitor');
    if ($scheme and $scheme =~ /"scheme":"([0-9A-Za-z+_.-]+)"/) {
      $scheme = $1;
      $scheme =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      return $scheme;
    }
  }
  if ($Wanage::HTTP::UseXForwardedScheme) {
    my $scheme = $_[0]->get_request_header ('X-Forwarded-Scheme');
    if ($scheme and $scheme =~ /\A[0-9A-Za-z+_.-]+\z/) {
      $scheme =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      return $scheme;
    }
    $scheme = $_[0]->get_request_header ('X-Forwarded-Proto');
    if ($scheme and $scheme =~ /\A[0-9A-Za-z+_.-]+\z/) {
      $scheme =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      return $scheme;
    }
  }
  return undef;
} # _url_scheme_by_proxy

sub original_url ($) {
  return $_[0]->{original_url} ||= do {
    my $handler = $_[0];
    
    my $url = $handler->get_meta_variable ('REQUEST_URI');
    $url = '' unless defined $url;
    $url = decode 'utf-8', $url;
    
    my $parsed_url = Wanage::URL->new_from_string ($url);
    if (defined $parsed_url->{scheme}) {
      unless ($Wanage::Interface::UseRequestURLScheme) {
        $parsed_url->set_scheme ($handler->url_scheme);
      }
    } else {
      $parsed_url->{scheme} = $handler->url_scheme;
      $parsed_url->{scheme_normalized} = $parsed_url->{scheme};
      $parsed_url->{scheme_normalized} =~ tr/A-Z/a-z/; ## ASCII case-insensitive
      
      my $host = ($Wanage::HTTP::UseXForwardedHost
                      ? $handler->get_meta_variable('HTTP_X_FORWARDED_HOST') 
                      : undef)
          || $handler->get_meta_variable ('HTTP_HOST')
          || ($handler->get_meta_variable ('SERVER_NAME') . ':' . 
              $handler->get_meta_variable ('SERVER_PORT'));
      if ($host =~ s/:([0-9]+)\z//) {
        $parsed_url->{port} = $1;
      }
      $parsed_url->{host} = $host;
      
      delete $parsed_url->{invalid} if $parsed_url->{path} =~ m{^(?:/|\z)};
    }
    
    $parsed_url;
  };
} # original_url

sub canon_url ($) {
  return $_[0]->{canon_url} ||= $_[0]->original_url->get_canon_url;
} # canon_url

sub onclose ($;$) {
  if (@_ > 1) {
    $_[0]->{onclose} = $_[1];
  }
  return $_[0]->{onclose} || sub { };
} # onclose

1;

=head1 LICENSE

Copyright 2012 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
