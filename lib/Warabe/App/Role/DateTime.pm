package Warabe::App::Role::DateTime;
use strict;
use warnings;
our $VERSION = '1.0';

sub epoch_param_as_datetime ($$) {
  my $v = $_[0]->bare_param ($_[1]);
  if (defined $v and $v =~ /\A-?[0-9]{1,13}\z/) {
    require DateTime;
    return DateTime->from_epoch (epoch => $v);
  }
  return undef;
} # epoch_param_as_datetime

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
