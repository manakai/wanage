package Warabe::App::Role::JSON;
use strict;
use warnings;
our $VERSION = '1.0';
use JSON::Functions::XS qw(perl2json_bytes json_bytes2perl);

sub request_json ($) {
  return $_[0]->{request_json}
      ||= json_bytes2perl ${$_[0]->http->request_body_as_ref || \''};
} # request_json

sub send_json ($$) {
  my $http = $_[0]->http;
  $http->set_response_header ('Content-Type' => 'application/json');
  $http->send_response_body_as_ref (\perl2json_bytes $_[1]);
  $http->close_response_body;
} # send_json

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
