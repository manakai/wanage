package Wanage::HTTP::MIMEType;
use strict;
use warnings;
our $VERSION = '2.0';
use Web::Encoding;

sub new_from_content_type ($$) {
  my ($class, $ct) = @_;

  ## This parsing is not strict per the spec definition, but does work
  ## enough for real-world HTTP messages, and in fact the spec does
  ## not define error handling at all.

  $ct = '' unless defined $ct;
  my @map;
  $ct =~ s{(\$\$[0-9]+\$\$|\"[^\"]*\"?)}{
    push @map, $1;
    '$$' . $#map . '$$';
  }ge;

  ## The MIME Sniffing spec requires the last Content-Type header
  ## field value used.
  $ct = [split /,/, $ct, -1]->[-1];
  $ct = '' unless defined $ct;

  my @param = split /;/, $ct;
  my %param;

  my $type = shift @param;
  if (defined $type and
      ## This rule is too restrictive than RFC 2616.
      $type =~ m{\A[\x09\x0A\x0D\x20]*([0-9A-Za-z_.+-]+/[0-9A-Za-z_.+-]+)[\x09\x0A\x0D\x20]*\z}) {
    $type = $1;
    $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

    ## RFC 2231's complex parameter syntax is not applied to HTTP.

    ## Specs do not define how to handle duplicate parameters.

    for my $param (@param) {
      $param =~ s{\$\$([0-9]+)\$\$}{$map[$1]}ge;
      if ($param =~ /\A[\x09\x0A\x0D\x20]*([0-9A-Za-z_.+-]+)[\x09\x0A\x0D\x20]*=[\x09\x0A\x0D\x20]*([^\x09\x0A\x0D\x20\x22]+|\x22[^\x22]*\x22)[\x09\x0A\x0D\x20]*\z/) {
        my $name = $1;
        my $value = $2;
        $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value =~ /^\x22/) {
          $value =~ s/^\x22//;
          $value =~ s/\x22$//;
        }

        ## Non-ASCII characters are left as is, for now.

        $param{$name} = $value;
      }
    }
  } else {
    ## According to the MIME Sniffing spec, invalid Content-Type field
    ## should be discarded entirely.

    $type = undef;
  }
  
  return bless {value => $type, params => \%param}, $class;
} # new_from_content_type

sub value ($) {
  return $_[0]->{value}; # or undef
} # value

sub set_value ($$) {
  my ($self, $value) = @_;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{value} = $value;
  if ($self->{onchange}) {
    $self->{onchange}->($self, $self->as_bytes);
  }
} # set_value

sub params ($) {
  return $_[0]->{params};
} # params

sub set_param ($$$) {
  my ($self, $name, $value) = @_;
  $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{params}->{$name} = $value;
  if ($self->{onchange}) {
    $self->{onchange}->($self, $self->as_bytes);
  }
} # set_param

sub is_html_mime_type ($) {
  return 'text/html' eq ($_[0]->value || '');
} # is_html_mime_type

sub is_xml_mime_type ($) {
  my $type = $_[0]->value || '';
  return
      $type eq 'text/xml' ||
      $type eq 'application/xml' ||
      $type =~ /\+xml\z/;
} # is_xml_mime_type

our $Sortkeys;

sub as_bytes ($) {
  my $self = shift;
  my $type = $self->value;
  return undef unless
      $type and $type =~ m{\A[0-9A-Za-z_+.-]+/[0-9A-Za-z_+.-]+\z};

  my $params = $self->params;
  my @param = keys %$params;
  @param = sort { $a cmp $b } @param if $Sortkeys;
  for (@param) {
    next if /[^0-9A-Za-z_+.-]/;
    my $value = $params->{$_};
    $value = '' unless defined $value;
    $value =~ s/[\x0A\x0D]+[\x09\x20]*/ /g;
    next if $value =~ /[^\x09\x20-\x7E]/;

    if ($value =~ /[^0-9A-Za-z_+.-]/) {
      ## XXX Should we escape " and \?
      $type .= '; ' . $_ . '="' . $value . '"';
    } else {
      $type .= '; ' . $_ . '=' . $value;
    }
  }

  return encode_web_utf8 $type; ## Drop utf8 flag, if any
} # as_bytes

1;

=head1 LICENSE

Copyright 2012-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
