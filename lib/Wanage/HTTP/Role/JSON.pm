package Wanage::HTTP::Role::JSON;
use strict;
use warnings;
our $VERSION = '1.0';
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);

sub request_json ($) {
  return $_[0]->{request_json}
      ||= json_bytes2perl ${$_[0]->request_body_as_ref || \''};
} # request_json

sub set_response_json ($$) {
  $_[0]->set_response_header ('Content-Type' => 'application/json');
  $_[0]->send_response_body_as_ref (\perl2json_bytes $_[1]);
  $_[0]->close_response_body;
} # set_response_json

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
