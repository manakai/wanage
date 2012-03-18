package Wanage::App;
use strict;
use warnings;
our $VERSION = '1.0';
use Encode;
use URL::PercentEncode qw(percent_decode_c);

## ------ Constructor ------

sub new_from_http ($$) {
  return bless {http => $_[1]}, $_[0];
} # new_from_http

## ------ Underlying HTTP object ------

sub http ($) {
  return $_[0]->{http};
} # http

## ------ Request data ------

sub path_segments ($) {
  $_[0]->{path_segments} ||= do {
    my $v = [map { percent_decode_c $_ }
             split m{/}, $_[0]->{http}->url->{path}, -1];
    shift @$v;
    require List::Ish;
    List::Ish->new ($v);
  };
} # path_segments

sub text_param ($$) {
  return $_[0]->{text_param}->{$_[1]} if exists $_[0]->{text_param}->{$_[1]};
  my $proto = $_[0]->{http};
  my $key = encode 'utf-8', $_[1];
  my $v = $proto->query_params->{$key}
      || $proto->request_body_params->{$key}
      || [];
  return $_[0]->{text_param}->{$_[1]} = decode 'utf-8', $v->[0] 
      if defined $v->[0];
  return $_[0]->{text_param}->{$_[1]} = undef;
} # text_param

sub text_param_list ($$) {
  return $_[0]->{text_param_list}->{$_[1]} ||= do {
    my $proto = $_[0]->{http};
    my $key = encode 'utf-8', $_[1];
    require List::Ish;
    List::Ish->new ([
      map { decode 'utf-8', $_ }
      @{$proto->query_params->{$key} or []},
      @{$proto->request_body_params->{$key} or []},
    ]);
  };
} # text_param_list

sub bare_param ($$) {
  my $proto = $_[0]->{http};
  return (($proto->query_params->{$_[1]} ||
           $proto->request_body_params->{$_[1]} ||
           [])->[0]);
} # bare_param

sub bare_param_list ($$) {
  return $_[0]->{bare_param_list}->{$_[1]} ||= do {
    my $proto = $_[0]->{http};
    require List::Ish;
    List::Ish->new ([
      @{$proto->query_params->{$_[1]} or []},
      @{$proto->request_body_params->{$_[1]} or []},
    ]);
  };
} # bare_param_list

## ------ Response construction ------

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/\"/&quot;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
}

sub send_plain_text ($$) {
  my $http = $_[0]->{http};
  $http->set_response_header ('Content-Type' => 'text/plain; charset=utf-8');
  $http->send_response_body_as_text ($_[1]);
  $http->close_response_body;
} # send_plain_text

sub send_html ($$) {
  my $http = $_[0]->{http};
  $http->set_response_header ('Content-Type' => 'text/html; charset=utf-8');
  $http->send_response_body_as_text ($_[1]);
  $http->close_response_body;
} # send_html

sub redirect_url_filter ($$) {
  return $_[1];
} # redirect_url_filter

sub send_redirect ($$;%) {
  my ($self, $url_as_string, %args) = @_;
  my $http = $self->{http};

  my $location_url = $http->url->resolve_string ('' . $url_as_string)
      ->get_canon_url;
  $location_url = $self->redirect_url_filter ($location_url);

  $http->set_status (302);
  $http->set_response_header (Location => $location_url->stringify);
  $http->set_response_header ('Content-Type' => 'text/html; charset=utf-8');

  $http->send_response_body_as_text
      (sprintf '<!DOCTYPE HTML><title>Moved</title><a href="%s">Moved</a>',
           htescape $location_url->stringify);
  $http->close_response_body;
} # send_redirect

sub send_error ($$;%) {
  my ($self, $code, %args) = @_;
  my $proto = $self->{http};
  $proto->set_status ($code ||= 400, $args{reason_phrase});
  $proto->set_response_header
      ('Content-Type' => 'text/plain; charset=us-ascii');
  $proto->send_response_body_as_ref (\$code);
  $proto->close_response_body;
} # send_error

## ------ Throw-or-process application model ------

sub execute ($$;%) {
  my ($self, $code, %args) = @_;
  eval {
    $code->();
    1;
  } or do {
    if ($@ and ref $@ and $@->isa ('Wanage::App::Done')) {
      ;
    } else {
      warn $@;
      if ($self->http->response_headers_sent) {
        ;
      } else {
        $self->send_error (500);
      }
    }
  };
} # execute

sub throw ($) {
  die bless {}, 'Wanage::App::Done';
} # throw

{
  package Wanage::App::Done;
  our $VERSION = '1.0';
}

sub throw_redirect ($$;%) {
  my $self = shift;
  $self->send_redirect (@_);
  $self->throw;
} # throw_redirect

sub throw_error ($$;%) {
  my $self = shift;
  $self->send_error (@_);
  $self->throw;
} # throw_error

## ------ Validation rules ------

our $AllowedURLSchemes ||= {
  http => 1,
  https => 1,
};

sub requires_valid_url_scheme ($) {
  my $url = $_[0]->{http}->url;
  unless ($AllowedURLSchemes->{$url->{scheme}}) {
    $_[0]->throw_error (400, reason_phrase => 'Unsupported URL Scheme');
  }
} # requires_valid_url_scheme

our $AllowedHostnamePattern ||= qr/.*/;

sub requires_valid_hostname ($) {
  my $url = $_[0]->{http}->url;
  if (not defined $url->{host} or 
      not $url->{host} =~ /^$AllowedHostnamePattern$/) {
    $_[0]->throw_error (400, reason_phrase => 'Bad hostname');
  }
} # requires_valid_hostname

our $MaxContentLength ||= 1024 * 1024;

sub requires_valid_content_length ($;%) {
  my ($self, %args) = @_;
  my $max = $args{max} || $MaxContentLength;
  my $length = $self->{http}->request_body_length;
  unless ($length <= $max) {
    $self->throw_error (413);
  }
} # requires_valid_content_length

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
