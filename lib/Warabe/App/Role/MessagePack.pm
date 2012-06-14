package Warabe::App::Role::MessagePack;
use strict;
use warnings;
our $VERSION = '1.0';
use Data::MessagePack;

sub mp_param {
  my $value = $_[0]->bare_param ($_[1]);
  if (defined $value) {
    local $@;
    return eval { Data::MessagePack->new->decode($value) };
  } else {
    return undef;
  }
}

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
