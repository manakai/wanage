package Wanage::HTTP::UA;
use strict;
use warnings;
our $VERSION = '1.0';

sub new_from_http_user_agent ($$) {
  return bless {ua => $_[1] || ''}, $_[0];
} # new_from_http_user_agent

sub is_ie ($)          { $_[0]->{ua} =~ /MSIE / }
sub is_iphone ($)      { $_[0]->{ua} =~ /iPhone|iPod/ }
sub is_ipad ($)        { $_[0]->{ua} =~ /iPad/ }
sub is_android ($)     { $_[0]->{ua} =~ /Android/ }
sub is_docomo1 ($)     { $_[0]->{ua} =~ m{^DoCoMo/(?:1\.|2\.[^(]+\(c100;)} }
sub is_docomo ($)      { $_[0]->{ua} =~ /^DoCoMo/ }
sub is_softbank ($)    { $_[0]->{ua} =~ /^(?:SoftBank|Vodafone)/ }
sub is_au ($)          { $_[0]->{ua} =~ /^KDDI-[A-Za-z0-9]+ UP\.Browser/ }
sub is_dsi ($)         { $_[0]->{ua} =~ /Nintendo DSi/ }
sub is_3ds ($)         { $_[0]->{ua} =~ /Nintendo 3DS/ }
sub is_ds ($)          { $_[0]->{ua} =~ /Nintendo 3?DSi?/ }
sub is_wii ($)         { $_[0]->{ua} =~ /Nintendo Wii/ }
sub is_ps3 ($)         { $_[0]->{ua} =~ /PLAYSTATION 3/ }
sub is_psp ($)         { $_[0]->{ua} =~ /PSP \(PlayStation Portable\)/ }
sub is_psvita ($)      { $_[0]->{ua} =~ /PlayStation Vita/ }
sub is_hatena_star ($) { $_[0]->{ua} =~ /Hatena Star UserAgent/ }

sub is_bot ($) {
  my $self = shift;
  return $self->{is_bot} if exists $self->{is_bot};
  return $self->{is_bot} =
      $self->{ua} =~ /[Bb][Oo][Tt]|[Ss][Pp][Ii][Dd][Ee][Rr]|^Y!|[Ss][Ll][Uu][Rr][Pp]/ ||
      $self->_is_galapagos_bot ||
      $self->is_hatena_star;
} # is_bot
sub _is_galapagos_bot ($) { $_[0]->{ua} =~ /Y!J-SRD|Y!J-MBS/ }

sub is_galapagos ($) {
  my $self = shift;
  return $self->{is_galapagos} if exists $self->{is_galapagos};
  return $self->{is_galapagos}
      = $self->is_docomo || $self->is_au || $self->is_softbank ||
        $self->_is_galapagos_bot;
} # is_galapagos

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
