package Upload;
use strict;
use warnings;
use Encode;
use URL::PercentEncode qw(percent_encode_c percent_encode_b);

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/\"/&quot;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
}

sub process ($$) {
  my ($class, $app) = @_;

  if ($app->http->request_method eq 'POST') {
    my $http = $app->http;
    $http->response_mime_type->set_value ('text/html');
    $http->response_mime_type->set_param (charset => 'utf-8');
    $http->send_response_body_as_text (q{<!DOCTYPE HTML>
<title>Uploaded data</title>

<h1>Params</h1>

<dl>});

    my $body_params = $http->request_body_params;
    for my $name (keys %$body_params) {
      $http->send_response_body_as_text
          (sprintf q{<dt>} . (htescape decode 'utf-8', $name) .
           join '', map { q{<dd>} . htescape decode 'utf-8', $_ } @{$body_params->{$name}});
    }
    
    $http->send_response_body_as_text (q{</dl>

<h1>Uploaded files</h1>

<dl>});

    my $uploads = $http->request_uploads;
    for my $name (keys %$uploads) {
      $http->send_response_body_as_text (q{<dt>} . htescape $name);
      for my $upload (@{$uploads->{$name}}) {
        $http->send_response_body_as_text
            (sprintf q{<dd><a href="data:%s,%s">%s (size %d)</a>},
             (htescape $upload->mime_type->as_bytes),
             (percent_encode_b scalar $upload->as_f->slurp),
             htescape $upload->filename,
             htescape $upload->size);
      }
    }

    $http->send_response_body_as_text (q{</dl>});
  } else {
    $app->send_html (q{<!DOCTYPE HTML>
<title>Upload</title>

<form method=post action=/upload enctype=multipart/form-data>
  <p><input type=text name=text value="" placeholder=type=text>
  <p><input type=file name=file1>
  <p><input type=file name=file2 multiple>
  <p><input type=submit name=submit>
</form>});
  }
} # process

1;

## License: Public Domain.
