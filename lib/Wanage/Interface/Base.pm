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

# XXX This method will be deleted due to lack of use cases
sub script_url ($) {
  my $handler = $_[0];

  my $scheme = $handler->url_scheme;
  
  my $host = $handler->get_meta_variable ('HTTP_HOST')
      || ($handler->get_meta_variable ('SERVER_NAME') . ':' . 
          $handler->get_meta_variable ('SERVER_PORT'));
  my $port;
  if ($host =~ s/:([0-9]+)\z//) {
    $port = $1;
  }

  my $path = $handler->get_meta_variable ('SCRIPT_NAME');
  $path = '' unless defined $path;
  my $path_info = $handler->get_meta_variable ('PATH_INFO');
  $path .= $path_info if defined $path_info;
  $path = '/' . $path unless $path =~ m{^/};
  $path =~ s{([\x00-\x20\x22\x23\x25<>\x5B-\x5E\x60\x7B-\x7D;=?\x7F-\xFF])}
      {sprintf '%%%02X', ord $1}ge;
  
  return Wanage::URL->new_from_parsed_url ({
    scheme => $scheme,
    scheme_normalized => $scheme,
    is_hierarchical => 1,
    host => $host,
    port => $port,
    path => $path,
    query => $handler->get_meta_variable ('QUERY_STRING'),
  });
} # script_url

sub original_url ($) {
  return $_[0]->{original_url} ||= do {
    my $handler = $_[0];
    
    my $url = $handler->get_meta_variable ('REQUEST_URI');
    $url = '' unless defined $url;
    $url = decode 'utf-8', $url;
    
    my $parsed_url = Wanage::URL->new_from_string ($url);
    if (defined $parsed_url->{scheme}) {
      #
    } else {
      $parsed_url->{scheme} = $handler->url_scheme;
      $parsed_url->{scheme_normalized} = $parsed_url->{scheme};
      $parsed_url->{scheme_normalized} =~ tr/A-Z/a-z/; ## ASCII case-insensitive
      
      my $host = $handler->get_meta_variable ('HTTP_HOST')
          || ($handler->get_meta_variable ('SERVER_NAME') . ':' . 
              $handler->get_meta_variable ('SERVER_PORT'));
      if ($host =~ s/:([0-9]+)\z//) {
        $parsed_url->{port} = $1;
      }
      $parsed_url->{host} = $host;
      
      delete $parsed_url->{invalid};
    }
    
    $parsed_url;
  };
} # original_url

sub canon_url ($) {
  return $_[0]->{canon_url} ||= $_[0]->original_url->get_canon_url;
} # canon_url

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
