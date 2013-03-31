package Warabe::App::Role::JSON;
use strict;
use warnings;
our $VERSION = '2.0';
use JSON::Functions::XS qw(perl2json_bytes json_bytes2perl);

sub request_json ($) {
  return $_[0]->{request_json}
      ||= json_bytes2perl ${$_[0]->http->request_body_as_ref || \''};
} # request_json

sub json_param ($$) {
    my $value = $_[0]->bare_param ($_[1]);
    if (defined $value) {
        return json_bytes2perl $value;
    } else {
        return undef;
    }
}

sub send_json ($$) {
  my $http = $_[0]->http;
  $http->set_response_header
      ('Content-Type' => 'application/json; charset=utf-8');
  $http->send_response_body_as_ref (\perl2json_bytes $_[1]);
  $http->close_response_body;
} # send_json

1;

=head1 LICENSE

Copyright 2012-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
