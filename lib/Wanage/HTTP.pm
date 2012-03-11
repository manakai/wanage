package Wanage::HTTP;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Encode;
require utf8;
use Scalar::Util qw(weaken);
use URL::PercentEncode qw(parse_form_urlencoded_b);

our @CARP_NOT = qw(
  Wanage::Interface::CGI Wanage::Interface::PSGI
  Wanage::HTTP::UA Wanage::HTTP::ClientIPAddr Wanage::HTTP::MIMEType
);

# ------ Constructor ------

sub new_cgi ($) {
  require Wanage::Interface::CGI;
  return bless {
    interface => Wanage::Interface::CGI->new_from_main,
  }, $_[0];
} # new_cgi

sub new_from_psgi_env ($$) {
  require Wanage::Interface::PSGI;
  return bless {
    interface => Wanage::Interface::PSGI->new_from_psgi_env ($_[1]),
  }, $_[0];
} # new_from_psgi_env

# ------ Request data ------

# ---- Request URL ----

sub url ($) {
  return $_[0]->{interface}->canon_url;
} # url

sub original_url ($) {
  return $_[0]->{interface}->original_url;
} # original_url

sub query_params ($) {
  return $_[0]->{query_params} ||= do {
    parse_form_urlencoded_b
        $_[0]->{interface}->get_meta_variable ('QUERY_STRING');
  };
} # query_params

# ---- Request method ----

sub request_method ($) {
  return $_[0]->{request_method} ||= do {
    my $rm = $_[0]->{interface}->get_meta_variable ('REQUEST_METHOD');
    my $rm_uc = $rm;
    if ($rm_uc =~ tr/a-z/A-Z/) {
      require Wanage::HTTP::Info;
      if ($Wanage::HTTP::Info::CaseInsensitiveMethods->{$rm_uc}) {
        $rm_uc;
      } else {
        $rm;
      }
    } else {
      $rm;
    }
  };
} # request_method

sub request_method_is_safe ($) {
  require Wanage::HTTP::Info;
  return $Wanage::HTTP::Info::SafeMethods->{$_[0]->request_method};
} # request_method_is_safe

sub request_method_is_idempotent ($) {
  require Wanage::HTTP::Info;
  return $Wanage::HTTP::Info::IdempotentMethods->{$_[0]->request_method};
} # request_method_is_idempotent

# ---- Request headers ----

sub get_request_header ($$) {
  return $_[0]->{interface}->get_request_header ($_[1]);
} # get_request_header

our $ClientIPAddrClass ||= 'Wanage::HTTP::ClientIPAddr';

sub client_ip_addr ($) {
  return $_[0]->{client_ip_addr} ||= do {
    eval qq{ require $ClientIPAddrClass } or die $@;
    $ClientIPAddrClass->new_from_interface ($_[0]->{interface});
  };
} # client_ip_addr

our $UAClass ||= 'Wanage::HTTP::UA';

sub ua ($) {
  return $_[0]->{ua} ||= do {
    eval qq{ require $UAClass } or die $@;
    $UAClass->new_from_http_user_agent
        ($_[0]->{interface}->get_request_header ('User-Agent'));
  };
} # ua

sub request_mime_type ($) {
  require Wanage::HTTP::MIMEType;
  return $_[0]->{request_mime_type}
      ||= Wanage::HTTP::MIMEType->new_from_content_type
          ($_[0]->{interface}->get_request_header ('Content-Type'));
} # request_mime_type

sub accept_langs ($) {
  return $_[0]->{accept_langs} if $_[0]->{accept_langs};

  ## This parsing is not strict per the spec definition, but does work
  ## enough for real-world HTTP messages, and in fact the spec does
  ## not define error handling at all.

  my $langs = $_[0]->{interface}->get_request_header ('Accept-Language');
  $langs = '' unless defined $langs;
  my @map;
  $langs =~ s{(\$\$[0-9]+\$\$|\"[^\"]*\"?)}{
    push @map, $1;
    '$$' . $#map . '$$';
  }ge;

  my @lang;
  for my $lang (split /,/, $langs) {
    my $q = 1;
    if ($lang =~ s/;[\x09\x0A\x0D\x20]*[Qq][\x09\x0A\x0D\x20]*=([^;]*)//) {
      $q = $1;
      $q =~ s/\A[\x09\x0A\x0D\x20]+//;
      $q =~ s/[\x09\x0A\x0D\x20]+\z//;
      $q =~ s{\$\$([0-9]+)\$\$}{$map[$1]}ge;
      $q =~ s{\x22([^\x22]*)\x22}{$1}g;
      if ($q =~ /^([0-9](?:\.[0-9]{1,3})?)/) {
        $q = 0 + $1;
        $q = 1 if $q > 1;
      } else {
        $q = 1;
      }
    } else {
      $q = 1;
    }
    next unless $q;
    if ($lang =~ /^[\x09\x0A\x0D\x20]*([0-9A-Za-z*-]+)/) {
      my $v = $1;
      $v =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      push @lang, [$v, $q];
    }
  }
  require List::Ish;
  return $_[0]->{accept_langs}
      = List::Ish->new ([sort { $b->[1] <=> $a->[1] } @lang])
          ->map (sub { $_->[0] })
          ->uniq_by_key (sub { $_ });
} # accept_langs

sub request_cookies {
  return $_[0]->{cookies} ||= do {
    my $cookie = $_[0]->get_request_header ('Cookie') || '';
    my $cookies = {};
    for (split /;/, $cookie) {
      my ($n, $v) = split /=/, $_, 2;
      next unless defined $v;
      $n =~ s/\A[\x09\x0A\x0D\x20]+//;
      $n =~ s/[\x09\x0A\x0D\x20]+\z//;
      next unless length $n;
      $v =~ s/\A[\x09\x0A\x0D\x20]+//;
      $v =~ s/[\x09\x0A\x0D\x20]+\z//;
      $cookies->{$n} = $v unless defined $cookies->{$n};
    }
    $cookies;
  };
} # request_cookies

sub request_auth ($) {
  my $auth = $_[0]->get_request_header ('Authorization') || '';
  if ($auth =~ s/^[\x09\x0A\x0D\x20]*[Bb][Aa][Ss][Ii][Cc][\x09\x0A\x0D\x20]+//) {
    $auth =~ s/[\x09\x0A\x0D\x20]+\z//;
    return {} if $auth =~ m{[^A-Za-z0-9+/=]};
    require MIME::Base64;
    my $decoded = MIME::Base64::decode_base64 ($auth);
    my ($userid, $password) = split /:/, $decoded, 2;
    return {auth_scheme => 'basic', userid => $userid, password => $password};
  } else {
    return {};
  }
} # request_auth

sub request_cache_control ($) {
  return $_[0]->{request_cache_control} ||= do {
    my $value = $_[0]->get_request_header ('Cache-Control');
    $value = '' unless defined $value;
    my @map;
    $value =~ s{(\$\$[0-9]+\$\$|\"[^\"]*\"?)}{
      push @map, $1;
      '$$' . $#map . '$$';
    }ge;
    my $directives = {};
    for (split /,/, $value) {
      s/^[\x09\x0A\x0D\x20]*([^\x09\x0A\x0D\x20=]+)// or next;
      my $name = $1;
      my $value = $1
          if s/^[\x09\x0A\x0D\x20]*=[\x09\x0A\x0D\x20]*([^\x09\x0A\x0D\x20]*)//;
      s/^[\x09\x0A\x0D\x20]+//;
      next if length $_;
      $name =~ s/\$\$([0-9]+)\$\$/$map[$1]/g;
      next if $name =~ /\"/;
      $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if (defined $value) {
        $value =~ s/\$\$([0-9]+)\$\$/$map[$1]/g;
        if ($value =~ /^"/ and $value =~ /"$/) {
          $value =~ s/^\"//;
          $value =~ s/\"$//;
        }
      }
      if (defined $directives->{$name}) {
        if (defined $value) {
          $directives->{$name} .= ',' . $value;
        }
      } else {
        $directives->{$name} = $value;
      }
    }
    $directives;
  };
} # request_cache_control

sub is_superreload ($) {
  return exists $_[0]->request_cache_control->{'no-cache'};
} # is_superreload

sub request_ims ($) {
  return $_[0]->{request_ims} if exists $_[0]->{request_ims};
  my $date = $_[0]->get_request_header ('If-Modified-Since');
  require Wanage::HTTP::Date;
  return $_[0]->{request_ims} = defined $date
      ? Wanage::HTTP::Date::parse_date ($date) : undef;
} # request_ims

# ---- Request body ----

sub request_body_as_ref ($) {
  return $_[0]->{request_body_as_ref}
      ||= $_[0]->{interface}->get_request_body_as_ref;
} # request_body_as_ref

sub request_body_params ($) {
  return $_[0]->{request_body_params} ||= do {
    my $ct = [split /;/, $_[0]->get_request_header ('Content-Type') || '', 2]->[0] || '';
    $ct =~ s/[\x09\x0A\x0D\x20]+\z//;
    $ct =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($ct eq 'application/x-www-form-urlencoded') {
      parse_form_urlencoded_b ${$_[0]->request_body_as_ref || \''};
    } elsif ($ct eq 'multipart/form-data') {
      # XXX
      {};
    } else {
      {};
    }
  };
} # request_body_params

# ------ Response construction ------

sub _ascii ($) {
  if (utf8::is_utf8 ($_[0])) {
    return encode 'utf8', $_[0];
  } else {
    return $_[0];
  }
} # _ascii

sub _u8 ($) {
  return encode 'utf-8', $_[0];
} # _u8

sub set_status ($$;$) {
  croak "You can no longer set the status" if $_[0]->{response_headers_sent};
  $_[0]->{response_headers}->{status} = $_[1];
  $_[0]->{response_headers}->{status_text} = $_[2];
} # set_status

sub add_response_header ($$$) {
  croak "You can no longer set a header" if $_[0]->{response_headers_sent};
  my ($self, $name, $value) = @_;
  my $i_name = $name;
  $i_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  push @{$self->{response_headers}->{headers}->{$i_name} ||= []},
      [$name => $value];
} # add_response_header

sub set_response_header ($$$) {
  croak "You can no longer set a header" if $_[0]->{response_headers_sent};
  my ($self, $name, $value) = @_;
  my $i_name = $name;
  $i_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{response_headers}->{headers}->{$i_name}
      = [[$name => $value]];
} # set_response_header

sub response_mime_type ($) {
  return $_[0]->{request_mime_type} ||= do {
    require Wanage::HTTP::MIMEType;
    my $headers = $_[0]->{response_headers}->{headers};
    my $mime = Wanage::HTTP::MIMEType->new_from_content_type
        ($headers->{'content-type'}
             ? $headers->{'content-type'}->[-1]->[1] : undef);
    weaken (my $self = $_[0]);
    $mime->{onchange} = sub {
      $self->set_response_header ('Content-Type' => $_[1] || '');
    };
    $mime;
  };
} # response_mime_type

sub set_response_cookie {
  my ($self, $name => $value, %args) = @_;

  if (not defined $value) {
    $value = '';
    $args{expires} ||= 0;
  }
  $name =~ tr/;=/__/;
  $value =~ tr/;/_/;
  
  if (defined $args{expires}) {
    my @expires = gmtime $args{expires};
    $args{expires} = sprintf '%s, %02d-%s-%04d %02d:%02d:%02d GMT',
        [qw(Sun Mon Tue Wed Thu Fri Sat Sun)]->[$expires[6]],
        $expires[3],
        [qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)]->[$expires[4]],
        $expires[5] + 1900,
        $expires[2],
        $expires[1],
        $expires[0];
  }

  my @attr = ((_ascii $name) . '=' . (_ascii $value));
  
  for (qw(domain path expires)) {
    my $value = $args{$_} or next;
    $value =~ tr/;/_/;
    push @attr, $_ . '=' . (_ascii $value);
  }
  
  for (qw(secure httponly)) {
    push @attr, $_ if $args{$_};
  }

  $self->add_response_header ('Set-Cookie' => join '; ', @attr);
} # set_response_cookie

sub set_response_auth {
  my ($self, $auth_scheme, %args) = @_;
  $args{realm} = '' unless defined $args{realm};
  if ($auth_scheme eq 'basic') {
    $args{realm} =~ tr/"/_/;
    $self->add_response_header
        ('WWW-Authenticate' => 'Basic realm="' . (_u8 $args{realm}) . '"');
  } else {
    croak "Auth-scheme |$auth_scheme| is not supported";
  }
} # set_response_auth

sub set_response_last_modified {
  my @time = gmtime $_[1];
  $_[0]->set_response_header
      ('Last-Modified' => sprintf '%s, %02d %s %04d %02d:%02d:%02d GMT',
           [qw(Sun Mon Tue Wed Thu Fri Sat Sun)]->[$time[6]],
           $time[3],
           [qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)]->[$time[4]],
           $time[5] + 1900,
           $time[2], $time[1], $time[0]);
} # set_response_last_modified

our $Sortkeys;

sub send_response_headers ($) {
  my $headers = $_[0]->{response_headers};
  my @headers = values %{$headers->{headers} or {}};
  @headers = sort { $a->[0]->[0] cmp $b->[0]->[0] } @headers if $Sortkeys;
  @headers = map {
    ## As a general rule, conformance to the relevant specifications,
    ## including server-application interface specifications and HTTP
    ## specification, is in the application's (or server's)
    ## responsitivility.  However, if some implementation failed to
    ## ensure the conformance to the header syntax, if can cause
    ## security vulnerability, so we reduce such possibility by
    ## forcing the following transformation:
    my ($name, $value) = @$_;
    $name =~ s/[^0-9A-Za-z_-]/_/g;
    $value =~ s/[\x0D\x0A]+[\x09\x20]*/ /g;
    [$name => $value];
  } map { @$_ } @headers;
  $_[0]->{interface}->send_response_headers
      (status => $headers->{status},
       status_text => $headers->{status_text},
       headers => \@headers);
  $_[0]->{response_headers_sent} = 1;
} # send_response_headers

sub send_response_body_as_text ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->send_response_body (encode 'utf-8', $_[1]);
} # send_response_body_as_text

sub send_response_body_as_ref ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->send_response_body (${$_[1]});
} # send_response_body_as_ref

sub close_response_body ($) {
  $_[0]->send_response_headers unless $_[0]->{response_headers_sent};
  $_[0]->{interface}->close_response_body;
} # close_response_body

sub send_response ($;%) {
  return shift->{interface}->send_response (@_);
} # send_response

sub DESTROY {
  if ($Wanage::HTTP::DetectLeak) {
    warn "Possible memory leak";
  }
}

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
