package test::Wanage::HTTP::MultipartFormData;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Wanage::HTTP::MultipartFormData;

sub _version : Test(1) {
  ok $Wanage::HTTP::MultipartFormData::VERSION;
} # _version

sub _parse : Test(48) {
  for my $test (
    ['', '', {}, {}],
    ['abc', "--abc\x0D\x0A", {}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0A}, {}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Abbbb\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz", "bbbb"]}, {}],
    ['abc def', qq{--abc def\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc def--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abcd', qq{--abcd\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A--abcd--\x0D\x0A}, {aa => ["xyz\x0D\x0A--abc--"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="\xE4\x80\x80"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {"\x{4000}" => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\xE4\x80\x80\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz\x{4000}"]}, {}],
    ['abc', qq{\x0D\x0A--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{zzz\x0D\x0A--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{Content-Disposition: form-data; name="bb"\x0D\x0A\x0D\x0Azzz\x0D\x0A--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0Acontent-disposition:form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0Aabcd}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc\x0D\x0A\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--ABC--\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz\x0D\x0A--ABC--"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc\x0D\x0AContent-type: text/html\x0D\x0Acontent-DISPOSITION: attachment; name="baaa daf"\x0D\x0A\x0D\x0Azzz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"], "baaa daf" => ["zzz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa"def"\x0D\x0A\x0D\x0Axyz\x0D\x0A--abc--\x0D\x0A}, {aa => ["xyz"]}, {}],
    ['abc', qq{--abc\x0D\x0AContent-Disposition: form-data; name="aa\x5Cdef"\x0D\x0A\x0D\x0A\x0D\x0A--abc--\x0D\x0A}, {"aa\\def" => [""]}, {}],
  ) {
    open my $fh, '<', \($test->[1]);
    my $length = length $test->[1];
    my $formdata = Wanage::HTTP::MultipartFormData->new_from_boundary
        ($test->[0]);
    $formdata->read_from_handle ($fh, $length);

    eq_or_diff $formdata->as_params_hashref, $test->[2];
    eq_or_diff $formdata->as_uploads_hashref, $test->[3];
  }
} # _parse

sub _parse_file_upload : Test(10) {
  my $boundary = "abcdef";
  my $data = qq{--abcdef\x0D\x0AContent-Disposition: form-data; name="name 2"; filename="fuga\\hoge.txt"\x0D\x0A\x0D\x0Aabc\x00\xFE\xcb--abc--xyz\x0D\x0A--abcdef--\x0D\x0A};
  open my $fh, '<', \$data;
  my $length = length $data;
  my $formdata = Wanage::HTTP::MultipartFormData->new_from_boundary
      ($boundary);
  $formdata->read_from_handle ($fh, $length);

  eq_or_diff $formdata->as_params_hashref, {};
  my $uploads = $formdata->as_uploads_hashref;
  eq_or_diff [keys %$uploads], ["name 2"];
  my $upload_list = $uploads->{"name 2"};
  is ref $upload_list, 'ARRAY';
  is scalar @$upload_list, 1;
  my $upload = $upload_list->[0];
  ok $upload->{is_file};
  is $upload->{content_type}, undef;
  is $upload->{content_length}, 16;
  is scalar file ($upload->{temp_file_name})->slurp, "abc\x00\xFE\xcb--abc--xyz";
  is $upload->{filename}, 'fuga\hoge.txt';
  is $upload->{name}, 'name 2';
} # _parse_file_upload

sub _parse_file_upload_2 : Test(10) {
  my $boundary = "abcdef";
  my $data = qq{--abcdef\x0D\x0Acontent-type: text/html; charset=us-ascii\x0D\x0AContent-Disposition: form-data; name="name 2"; filename="fuga\\hoge.txt"\x0D\x0A\x0D\x0Aabc\x00\xFE\xcb--abc--xyz\x0D\x0A--abcdef--};
  open my $fh, '<', \$data;
  my $length = length $data;
  my $formdata = Wanage::HTTP::MultipartFormData->new_from_boundary
      ($boundary);
  $formdata->read_from_handle ($fh, $length);

  eq_or_diff $formdata->as_params_hashref, {};
  my $uploads = $formdata->as_uploads_hashref;
  eq_or_diff [keys %$uploads], ["name 2"];
  my $upload_list = $uploads->{"name 2"};
  is ref $upload_list, 'ARRAY';
  is scalar @$upload_list, 1;
  my $upload = $upload_list->[0];
  ok $upload->{is_file};
  is $upload->{content_type}, "text/html; charset=us-ascii";
  is $upload->{content_length}, 16;
  is scalar file ($upload->{temp_file_name})->slurp, "abc\x00\xFE\xcb--abc--xyz";
  is $upload->{filename}, 'fuga\hoge.txt';
  is $upload->{name}, 'name 2';
} # _parse_file_upload_2

sub _parse_file_upload_multiple : Test(10) {
  my $boundary = "abcdef";
  my $data = qq{--abcdef\x0D\x0Acontent-type: text/html; charset=us-ascii\x0D\x0AContent-Disposition: form-data; name="name 2"; filename="fuga\\hoge.txt"\x0D\x0A\x0D\x0Aabc\x00\xFE\xcb--abc--xyz\x0D\x0A--abcdef\x0D\x0AContent-Disposition:form-data; name="name 2"; filename="hpoge.txt"\x0D\x0A\x0D\x0Aabx\xE0\x81\x0D\x0A--abcdef\x0D\x0AContent-Disposition: form-data; name="name 2"; filename=""\x0D\x0A\x0D\x0A\x0D\x0A--abcdef--};
  open my $fh, '<', \$data;
  my $length = length $data;
  my $formdata = Wanage::HTTP::MultipartFormData->new_from_boundary
      ($boundary);
  $formdata->read_from_handle ($fh, $length);

  eq_or_diff $formdata->as_params_hashref, {"name 2" => [""]};
  my $uploads = $formdata->as_uploads_hashref;
  eq_or_diff [keys %$uploads], ["name 2"];
  my $upload_list = $uploads->{"name 2"};
  is ref $upload_list, 'ARRAY';
  is scalar @$upload_list, 2;
  is scalar file ($upload_list->[0]->{temp_file_name})->slurp, "abc\x00\xFE\xcb--abc--xyz";
  is $upload_list->[0]->{filename}, 'fuga\hoge.txt';
  is scalar file ($upload_list->[1]->{temp_file_name})->slurp, "abx\xE0\x81";
  is $upload_list->[1]->{filename}, 'hpoge.txt';

  undef $formdata;
  ng -f $upload_list->[0]->{temp_file_name};
  ng -f $upload_list->[1]->{temp_file_name};
} # _parse_file_upload_multiple

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
