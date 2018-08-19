package Wanage::Interface::PSGI;
use strict;
use warnings;
our $VERSION = '3.0';
use Wanage::Interface::Base;
push our @ISA, qw(Wanage::Interface::Base);
use Carp;
use Web::Encoding;

# ------ Constructor ------

sub new_from_psgi_env ($$) {
  #my ($class, $env) = @_;
  return bless {env => $_[1]}, $_[0];
} # new_from_psgi_env

# ------ Request data ------

sub url_scheme ($) {
  return $_[0]->_url_scheme_by_proxy || $_[0]->{env}->{'psgi.url_scheme'};
} # url_scheme

sub get_meta_variable ($$) {
  #my ($self, $name) = @_;
  return $_[0]->{env}->{$_[1]};
} # get_meta_variable

sub get_request_body_as_ref ($) {
  my $length = $_[0]->{env}->{CONTENT_LENGTH};
  return undef unless defined $length;
  croak "Request body has already been read" if $_[0]->{request_body_read};
  my $buf = '';
  $_[0]->{env}->{'psgi.input'}->read ($buf, $length);
  croak "PSGI error: premature end of input"
      unless $length == length $buf;
  $_[0]->{request_body_read} = 1;
  return \$buf;
} # get_request_body_as_ref

sub get_request_body_as_handle ($) {
  my $length = $_[0]->{env}->{CONTENT_LENGTH};
  return undef unless defined $length;
  croak "Request body has already been read" if $_[0]->{request_body_read};
  $_[0]->{request_body_read} = 1;
  return $_[0]->{env}->{'psgi.input'};
} # get_request_body_as_handle

# ------ Response ------

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
  $self->{response} ||= [200, []];
  $self->{response}->[0] = $args{status} if defined $args{status};
  $self->{response}->[1] = [map { 
    my $s = utf8::is_utf8 ($_) ? encode_web_utf8 $_ : $_;
    $s =~ s/[\x0D\x0A]+[\x09\x20]*/ /g;
    $s;
  } map { ($_->[0] => $_->[1]) } @{$args{headers}}]
      if $args{headers};
  if ($self->{env}->{'psgi.streaming'}) {
    if ($self->{psgi_writer_getter}) {
      $self->{psgi_writer} = $self->{psgi_writer_getter}->($self->{response});
      delete $self->{psgi_writer_getter};
    }
  } else {
    $self->{response}->[2] ||= [];
  }
  $self->{response_headers_sent} = 1;
} # send_response_headers

sub send_response_body ($$) {
  my $self = $_[0];
  croak "Response body is already closed" if $self->{response_body_closed};
  $self->send_response_headers;
  if ($self->{env}->{'psgi.streaming'}) {
    if ($self->{psgi_writer}) {
      eval {
        $self->{psgi_writer}->write ($_[1]);
        1;
      } or carp $@;
    } else {
      push @{$self->{response_body} ||= []}, $_[1];
    }
  } else {
    push @{$self->{response}->[2]}, $_[1];
  }
} # send_response_body

sub close_response_body ($) {
  my $self = shift;
  croak "Response body is already closed" if $self->{response_body_closed};
  $self->send_response_headers;
  $self->{response_body_closed} = 1;
  $self->onclose->();
  if ($self->{psgi_writer}) {
    $self->{psgi_writer}->close;
    $self->{psgi_writer_closed_cv}->send if $self->{psgi_writer_closed_cv};
  }
} # close_response_body

sub send_response ($;%) {
  my ($self, %args) = @_;
  my $code = $args{onready};
  croak "Response has already been sent" if $self->{response_sent};
  $self->{response_sent} = 1;
  if ($AnyEvent::VERSION) {
    # <http://search.cpan.org/dist/AnyEvent/lib/AnyEvent.pm#AnyEvent-%3Enow_update>
    AnyEvent->now_update;
  }
  if ($self->{env}->{'psgi.streaming'}) {
    $self->{response} ||= [200, []];
    return sub {
      if ($self->{response_headers_sent}) {
        $self->{psgi_writer} = $_[0]->($self->{response});
        for (@{$self->{response_body} or []}) {
          eval {
            $self->{psgi_writer}->write ($_);
            1;
          } or carp $@;
        }
        delete $self->{response_body};
        if ($self->{response_body_closed}) {
          $self->{psgi_writer}->close;
          $self->{psgi_writer_closed_cv}->send
              if $self->{psgi_writer_closed_cv};
          $code->() if $code;
        } else {
          $code->() if $code;
        }
      } else {
        $self->{psgi_writer_getter} = $_[0];
        $code->() if $code;
      }
      if (not $self->{response_body_closed} and
          not $self->{env}->{'psgi.nonblocking'} and
          $AnyEvent::VERSION) {
        ($self->{psgi_writer_closed_cv} = AE::cv ())->recv;
      }
    };
  } else { # not streaming
    $code->() if $code;
    if (not $self->{response_body_closed} and
        not $self->{env}->{'psgi.nonblocking'} and
        $AnyEvent::VERSION) {
      ($self->{psgi_writer_closed_cv} = AE::cv ())->recv;
    } elsif (not $self->{response_body_closed}) {
      carp "Response body is not explicitly closed";
      $self->close_response_body;
    }
    return $self->{response};
  } # streaming
} # send_response

sub DESTROY {
  my $self = shift;
  ## Skip these checks if the interface object is only used to
  ## retrieve data from the env and is not intended to be used to
  ## construct the response.
  if ($self->{response}) {
    if ($self->{psgi_writer_getter}) {
      warn "Response is discarded without its headers sent\n";
    }
    $self->close_response_body unless $self->{response_body_closed};
    unless ($self->{response_sent}) {
      warn "Response is discarded before it is sent\n";
    }
  }
} # DESTROY

1;

=head1 LICENSE

Copyright 2012-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
