package Warabe::App;
use strict;
use warnings;
our $VERSION = '5.0';
use Web::Encoding;
use Web::URL::Encoding qw(percent_decode_c);
use Time::HiRes qw(gettimeofday tv_interval);
use Scalar::Util qw(weaken);

## ------ Constructor ------

sub new_from_http ($$) {
  my $app = bless {http => $_[1], start_time => [gettimeofday]}, $_[0];
  $app->{http}->onclose (sub {
    $app->{elapsed_time} = tv_interval $app->{start_time};
    $app->onclose->();
    undef $app;
  });
  return $app;
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
  my $key = encode_web_utf8 $_[1];
  my $v = $proto->query_params->{$key}
      || $proto->request_body_params->{$key}
      || [];
  return $_[0]->{text_param}->{$_[1]} = decode_web_utf8 $v->[0]
      if defined $v->[0];
  return $_[0]->{text_param}->{$_[1]} = undef;
} # text_param

sub text_param_list ($$) {
  return $_[0]->{text_param_list}->{$_[1]} ||= do {
    my $proto = $_[0]->{http};
    my $key = encode_web_utf8 $_[1];
    require List::Ish;
    List::Ish->new ([
      map { decode_web_utf8 $_ }
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

  my $use_refresh = $args{refresh};
  my $status = $args{status};
  if (not defined $status) {
    $status = $use_refresh ? 200 : 302;
  }
  
  $http->set_status ($status, $args{reason_phrase});
  $http->set_response_header ('Content-Type' => 'text/html; charset=utf-8');

  my $hurl = htescape $location_url->stringify;
  my $refresh = '';
  if ($use_refresh) {
    $refresh = sprintf '<meta http-equiv=Refresh content="0;url=%s">', $hurl;
  } else {
    $http->set_response_header (Location => $location_url->stringify);
  }

  $http->send_response_body_as_text
      (sprintf '<!DOCTYPE HTML><html lang=en><meta name=robots content="NOINDEX,NOARCHIVE"><meta name=referrer content=origin-when-cross-origin>%s<title>Moved</title><a href="%s">Next</a></html>', $refresh, $hurl);
  
  $http->close_response_body;
} # send_redirect

sub send_error ($$;%) {
  my ($self, $code, %args) = @_;
  my $proto = $self->{http};
  $proto->set_status ($code ||= 400, $args{reason_phrase});
  $proto->set_response_header
      ('Content-Type' => 'text/plain; charset=us-ascii');
  $proto->send_response_body_as_text
      (defined $args{reason_phrase}
           ? $code . ' ' . $args{reason_phrase} : $code)
      unless $code == 204 or $code == 304 or $self->http->request_method eq 'HEAD';
  $proto->close_response_body;
} # send_error

## ------ Throw-or-process application model ------

sub execute ($$;%) {
  my ($self, $code, %args) = @_;
  eval {
    $code->();
    1;
  } or do {
    if ($@ and ref $@ and $@->isa ('Warabe::App::Done')) {
      ;
    } else {
      $self->onexecuteerror->($@);
      if ($self->http->response_headers_sent) {
        ;
      } else {
        $self->send_error (500);
      }
    }
  };
} # execute

sub throw ($) {
  die bless {}, 'Warabe::App::Done';
} # throw

## ------ Promise-based application model ------

our $PromiseClass ||= 'Promise';

sub execute_by_promise ($$) {
  my ($app, $code) = @_;
  my ($ok, $error);
  eval qq{ require $PromiseClass } or die $@;
  my $p = $PromiseClass->new (sub {
    ($ok, $error) = @_;
  })->then ($code)->catch (sub {
    $app->onexecuteerror->($_[0]) unless UNIVERSAL::isa ($_[0], 'Warabe::App::Done');
    unless ($app->http->response_headers_sent) {
      $app->send_error (500);
    }
  })->catch (sub {
    warn $_[0];
  });
  return $app->http->send_response (onready => sub { $ok->() });
} # execute_by_promise

sub onclose ($;$) {
  if (@_ > 1) {
    $_[0]->{onclose} = $_[1];
  }
  return $_[0]->{onclose} || sub { };
} # onclose

sub onexecuteerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onexecuteerror} = $_[1];
  }
  return $_[0]->{onexecuteerror} ||= sub {
    warn $_[0];
  }
} # onexecuteerror

sub elapsed_time ($) {
  return $_[0]->{elapsed_time};
} # elapsed_time

{
  package Warabe::App::Done;
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
    $_[0]->throw_error (400, reason_phrase => 'Unsupported URL scheme');
  }
} # requires_valid_url_scheme

sub requires_https ($) {
  my $self = shift;
  my $url = $self->{http}->url;
  if ($url->{scheme} eq 'https') {
    #
  } elsif ($self->{http}->request_method_is_safe) {
    $url = $url->clone;
    $url->set_scheme ('https');
    $self->throw_redirect ($url->stringify);
  } else {
    $self->throw_error (400, reason_phrase => 'Unsupported URL scheme');
  }
} # requires_https

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

our $AllowedMIMETypes = {
  'application/x-www-form-urlencoded' => 1,
  'multipart/form-data' => 1,
};

sub requires_mime_type ($;$) {
  my $self = shift;
  my $allowed = shift || $AllowedMIMETypes;
  my $mime = $self->http->request_mime_type->value || '';
  if (not $mime and not $self->http->request_body_length) {
    ;
  } elsif ($allowed->{$mime}) {
    ;
  } else {
    $self->throw_error (415);
  }
} # requires_mime_type

our $AllowedRequestMethods = {
  'GET' => 1, 'HEAD' => 1, 'POST' => 1,
};

sub requires_request_method ($;$) {
  my $self = shift;
  my $allowed = shift || $AllowedRequestMethods;
  unless ($allowed->{$self->http->request_method}) {
    $self->http->set_response_header
        (Allow => join ',', sort grep { $allowed->{$_} } keys %$allowed);
    $self->throw_error (405);
  }
} # requires_request_method

sub requires_basic_auth ($$;%) {
  my ($self, $allowed, %args) = @_;
  my $http = $self->http;

  my $auth = $http->request_auth;
  if ($auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
    my $password = $allowed->{$auth->{userid}};
    if (defined $password and
        defined $auth->{password} and
        $password eq $auth->{password}) {
      return;
    }
  }

  $http->set_status (401);
  $http->set_response_auth ('basic', realm => $args{realm});
  $http->set_response_header
      ('Content-Type' => 'text/plain; charset=us-ascii');
  $http->send_response_body_as_ref (\'401 Authorization required');
  $http->close_response_body;
  $self->throw;
} # requires_basic_auth

sub requires_same_origin ($) {
  my $origin = $_[0]->http->get_request_header ('Origin');
  my $url_origin = $_[0]->http->url->ascii_origin;
  if (not defined $origin or
      not defined $url_origin or
      $origin =~ /,/ or
      $origin ne $url_origin) {
    $_[0]->throw_error (400, reason_phrase => 'Bad origin');
  }
} # requires_same_origin

sub requires_same_origin_or_referer_origin ($) {
  my $url_origin = $_[0]->http->url->ascii_origin;
  return $_[0]->throw_error (400, reason_phrase => 'Bad origin')
      unless defined $url_origin;

  my $origin = $_[0]->http->get_request_header ('Origin');
  if (defined $origin) {
    if ($origin =~ /,/ or $origin ne $url_origin) {
      return $_[0]->throw_error (400, reason_phrase => 'Bad origin');
    } else {
      return;
    }
  }

  my $referer = $_[0]->http->get_request_header ('Referer');
  if (defined $referer) {
    my $u = $_[0]->http->url->resolve_string ($referer)->get_canon_url;
    my $o = $u->ascii_origin;
    if (defined $o and $o eq $url_origin) {
      return;
    } else {
      return $_[0]->throw_error (400, reason_phrase => 'Bad origin');
    }
  }

  return $_[0]->throw_error (400, reason_phrase => 'Bad origin');
} # requires_same_origin_or_referer_origin

sub DESTROY ($) {
  local $@;
  eval { die };
  warn "Possible memory leak detected (Warabe::App)\n"
      if $@ =~ /during global destruction/;
} # DESTROY

1;

=head1 LICENSE

Copyright 2012-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
