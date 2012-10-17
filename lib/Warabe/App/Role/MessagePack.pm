package Warabe::App::Role::MessagePack;
use strict;
use warnings;
our $VERSION = '1.0';
use MIME::Base64 qw(decode_base64url);
use Data::MessagePack;

sub mp_param {
  my $value = $_[0]->bare_param ($_[1]);
  if (defined $value) {
    local $@;
    return eval { Data::MessagePack->new->decode($value) } || do {
      if ($@) {
        warn $@;
      }
      undef;
    };
  } else {
    return undef;
  }
}

sub mpb64_param {
  my $value = $_[0]->bare_param ($_[1]);
  if (defined $value) {
    local $@;
    return eval { Data::MessagePack->new->decode(decode_base64url $value) } || do {
      if ($@) {
        warn $@;
      }
      undef;
    };
  } else {
    return undef;
  }
}

sub send_mp ($$) {
  my $http = $_[0]->http;
  $http->set_response_header ('Content-Type' => 'application/x-msgpack');
  $http->send_response_body_as_ref (\Data::MessagePack->new->encode ($_[1]));
  $http->close_response_body;
} # send_mp

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
