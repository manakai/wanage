package test::Wanage::HTTP::ClientIPAddr;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Wanage::Envs;
use Wanage::HTTP;
use Wanage::HTTP::ClientIPAddr;

sub _version : Test(1) {
  ok $Wanage::HTTP::ClientIPAddr::VERSION;
} # _version

sub _new_from_interface : Test(2) {
  my $https = new_https_for_interfaces
      env => {REMOTE_ADDR => '10.2.4.11'};
  for my $http (@$https) {
    my $ip = Wanage::HTTP::ClientIPAddr->new_from_interface
        ($http->{interface});
    is $ip->as_text, '10.2.4.11';
  }
} # _new_from_interface

sub _addrs : Test(30) {
  for my $test (
    {result => undef},
    {addr => '', result => undef},
    {addr => '10.5.11.124', result => '10.5.11.124'},
    {addr => '00010.5.011.124', result => '8.5.9.124'}, # Stupid!
    {addr => '0x10.5.11.124', result => '16.5.11.124'}, # Heh!
    {addr => '10.5.255.124', result => '10.5.255.124'},
    {addr => '256.5.11.124', result => undef},
    {addr => '10.5.11.124,10.3.11.3', result => undef},
    {addr => ' 10.5.11.124 ', result => undef},
    {addr => '0', result => '0.0.0.0'},
    {addr => '0.100', result => '0.0.0.100'},
    {addr => '0.6555', result => '0.0.25.155'},
    {addr => '::10.5.4.11', result => '::a05:40b'},
    {addr => '::10.11', result => undef},
    {addr => '::', result => '::'},
    {addr => '0:abcC:001:23::', result => '0:abcc:1:23::'},
    {addr => '::124::', result => undef},
    {addr => ': :', result => undef},
    {addr => '[::]', result => undef},
    {addr => '[120:aab:44:c::]', result => undef},
    {addr => '0:0abcC:001:23::', result => undef},
    {addr => '10.5.11.124', for => '', result => '10.5.11.124'},
    {addr => '10.5.11.124', for => '192.168.51.44', result => '192.168.51.44'},
    {addr => '10.5.11.124', for => '192.168.51.44,', result => '192.168.51.44'},
    {addr => '10.5.11.124', for => ' 192.168.51.44 ',
     result => '192.168.51.44'},
    {addr => '10.5.11.124', for => '192.168.51.44,10.4.111.21',
     result => '10.4.111.21'},
    {addr => '10.5.11.124', for => '192.168.51.44,, 10.4.111.21',
     result => '10.4.111.21'},
    {addr => '10.5.11.124', for => '192.168.51.44,0::31:abc',
     result => '::31:abc'},
    {addr => '10.5.11.124', for => 'unknown', result => '10.5.11.124'},
    {addr => '10.5.11.124', for => '10.2.11.1,unknown', result => '10.2.11.1'},
  ) {
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      REMOTE_ADDR => $test->{addr},
      HTTP_X_FORWARDED_FOR => $test->{for},
    };
    my $ip = Wanage::HTTP::ClientIPAddr->new_from_interface
        ($http->{interface});
    is $ip->as_text, $test->{result};
  }
} # _addrs

sub _select_addr_subclassed : Test(2) {
  {
    package test::my::ipaddr::select;
    push our @ISA, 'Wanage::HTTP::ClientIPAddr';
    sub select_addr {
      return $_[0]->{addrs}->grep (sub { not /100/ })->[-1];
    }
  }

  {
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      REMOTE_ADDR => '10.5.10.3',
      HTTP_X_FORWARDED_FOR => '10.3.20.100,5.10.55.1,40.1.100.12',
    };
    my $ip = test::my::ipaddr::select->new_from_interface ($http->{interface});
    is $ip->as_text, '5.10.55.1';
  }
  {
    my $http = with_cgi_env { Wanage::HTTP->new_cgi } {
      REMOTE_ADDR => '10.5.100.3',
      HTTP_X_FORWARDED_FOR => '10.3.20.100,5.100.55.1,40.1.100.12',
    };
    my $ip = test::my::ipaddr::select->new_from_interface ($http->{interface});
    is $ip->as_text, undef;
  }
} # _select_addr_subclassed

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
