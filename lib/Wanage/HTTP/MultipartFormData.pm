package Wanage::HTTP::MultipartFormData;
use strict;
use warnings;
our $VERSION = '1.0';
use File::Temp;

sub new_from_boundary ($$) {
  return bless {
    boundary => $_[1],
    body_parts => [],
  }, $_[0];
} # new_from_boundary

sub read_from_handle ($$$) {
  my ($self, $fh, $length) = @_;
  $self->{buffer} = '';
  $self->{state} = 'preamble';
  while ($length > 0) {
    $length -= $fh->read
        ($self->{buffer},
         $length < 8192 ? $length : 8192,
         length $self->{buffer});
    $self->spin;
    last if $self->{state} eq 'done';
  }
} # read_from_handle

sub spin {
  my $self = shift;
  while (1) {
    if ($self->{state} =~ /^(preamble|boundary|header|body)$/) {
      my $method = "parse_$1";
      return unless $self->$method;
    } else {
      die "Unknown state: |$self->{state}|";
    }
  }
}

sub parse_preamble {
  my $self = shift;
  my $index = index($self->{buffer}, '--' . $self->{boundary});
  unless ($index >= 0) {
    return 0;
  }
  
  # replace preamble with CRLF so we can match dash-boundary as delimiter
  substr ($self->{buffer}, 0, $index, "\x0D\x0A");
  $self->{state} = 'boundary';
  return 1;
}

sub parse_boundary {
  my $self = shift;

  if (index ($self->{buffer},
             "\x0D\x0A--" . $self->{boundary} . "\x0D\x0A") == 0) {
    substr ($self->{buffer}, 0, 6 + length ($self->{boundary}), '');
    push @{$self->{body_parts}}, {content_length => 0};
    $self->{state} = 'header';
    return 1;
  }

  if (index ($self->{buffer}, "\x0D\x0A--" . $self->{boundary} . "--") == 0) {
    $self->{state} = 'done';
    return 0;
  }
  
  return 0;
}

sub parse_header {
  my $self = shift;
  my $index = index ($self->{buffer}, "\x0D\x0A\x0D\x0A");

  ## NOTE: This code does not handle the case headers are immediately
  ## followed by a delimiter (which would be an invalid MIME entity,
  ## however).
  
  unless ( $index >= 0 ) {
    return 0;
  }
  
  my $header = substr ($self->{buffer}, 0, $index);
  substr ($self->{buffer}, 0, $index + 4, '');

  my @headers;
  for (split /\x0D\x0A/, $header) {
    if (@headers and s/^[\x09\x20]+//) {
      $headers[-1]->[1] .= $_;
    } else {
      push @headers, [split /[\x09\x20]*:[\x09\x20]*/, $_, 2];
      @{$headers[-1]} = ('', $headers[-1]->[0])
          if not defined $headers[-1]->[1];
      $headers[-1]->[0] =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    }
  }

  for (@headers) {
    if ($_->[0] eq 'content-type') {
      $self->{body_parts}->[-1]->{content_type} = $_->[1];
    } elsif ($_->[0] eq 'content-disposition') {
      $self->{body_parts}->[-1]->{content_disposition} = $_->[1];
    }
  }

  $self->{state} = 'body';
  return 1;
}

sub parse_body {
  my $self = shift;
  my $part = $self->{body_parts}->[-1];
  my $index = index ($self->{buffer}, "\x0D\x0A--" . $self->{boundary});
  if ($index < 0) {
    # make sure we have enough buffer to detect end delimiter
    my $length = length ($self->{buffer}) - (length ($self->{boundary}) + 8);

    unless ($length > 0) {
      return 0;
    }

    if ($part->{fh}) {
      $part->{fh}->write (substr ($self->{buffer}, 0, $length, ''), $length);
    } else {
      $part->{data} .= substr ($self->{buffer}, 0, $length, '');
    }
    $part->{content_length} += $length;
    $part->{incomplete} = 1;
    $self->process_last_body_part;
    return 0;
  }

  if ($part->{fh}) {
    $part->{fh}->write (substr ($self->{buffer}, 0, $index, ''), $index);
  } else {
    $part->{data} .= substr ($self->{buffer}, 0, $index, '');
  }
  $part->{content_length} += $index;
  $self->process_last_body_part (done => 1);

  $self->{state} = 'boundary';

  return 1;
}

sub process_last_body_part ($;%) {
  my ($self, %args) = @_;
  my $part = $self->{body_parts}->[-1];

  unless ($part->{headers_parsed}) {
    my $disp = $part->{content_disposition} || '';
    if ($disp =~ / name="([^"]*)"/) {
      $part->{name} = $1;
    }
    if ($disp =~ / filename="([^"]*)"/) {
      $part->{filename} = $1;
      $part->{is_file} = 1;
    }
    delete $part->{content_disposition};
    
    $part->{headers_parsed} = 1;
  }
  
  if ($args{done} and $part->{content_length} == 0) {
    delete $part->{is_file};
  }

  if ($part->{is_file}) {
    if ($part->{fh}) {
      ;
    } else {
      $self->{tempdir} ||= File::Temp->newdir;
      $part->{fh} = File::Temp->new (DIR => $self->{tempdir}, UNLINK => 0);
      $part->{temp_file_name} = $part->{fh}->filename;
      $part->{fh}->write ($part->{data}, length $part->{data})
          if length $part->{data};
      delete $part->{data};
    }
  }

  if ($args{done}) {
    $part->{fh}->close if $part->{fh};
    delete $part->{fh};
    delete $part->{headers_parsed};
    delete $part->{incomplete};
  }
} # process_last_body_part

sub as_params_hashref ($) {
  my $self = shift;
  my $hashref = {};
  for my $part (@{$self->{body_parts}}) {
    next if $part->{incomplete};
    next if $part->{is_file};
    next unless defined $part->{name};
    push @{$hashref->{$part->{name}} ||= []}, $part->{data};
  }
  return $hashref;
} # as_params_hashref

sub as_uploads_hashref ($) {
  my $self = shift;
  my $hashref = {};
  for my $part (@{$self->{body_parts}}) {
    next if $part->{incomplete};
    next unless $part->{is_file};
    next unless defined $part->{name};
    push @{$hashref->{$part->{name}} ||= []}, $part;
        # is_file
        # name
        # filename
        # temp_file_name
        # content_type
        # content_length
    bless $part, 'Wanage::HTTP::MultipartFormData::Upload'
        if ref $part eq 'HASH';
  }
  return $hashref;
} # as_uploads_hashref

package Wanage::HTTP::MultipartFormData::Upload;
our $VERSION = '1.0';
use Encode;

sub name ($) {
  return $_[0]->{name};
} # name

sub filename ($) {
  return $_[0]->{decoded_filename} ||= decode 'utf-8', $_[0]->{filename};
} # filename

sub size ($) {
  return $_[0]->{content_length};
} # size

sub mime_type ($) {
  require Wanage::HTTP::MIMEType;
  return $_[0]->{mime_type} ||= Wanage::HTTP::MIMEType->new_from_content_type
      ($_[0]->{content_type});
} # mime_type

sub as_f ($) {
  require Path::Class;
  return $_[0]->{temp_f} ||= Path::Class::file ($_[0]->{temp_file_name});
} # as_f

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
