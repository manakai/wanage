package test::Wanage::HTTP::UA;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Wanage::HTTP::UA;

sub _version : Test(1) {
  ok $Wanage::HTTP::UA::VERSION;
} # _version

sub _is_ua : Test(936) {
  for my $test (
    {value => undef},
    {value => ''},
    {value => 0},
    {value => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.0.3705)',
     ie => 1},
    {value => 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0; Trident/5.0)',
     ie => 1},
    {value => 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0; Sleipnir/2.9.8)',
     ie => 1},
    {value => 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; SLCC1; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30618; Lunascape 4.7.3)',
     ie => 1},
    {value => 'Opera/9.61 (Windows NT 5.1; U; ja) Presto/2.1.1'},
    {value => 'Mozilla/4.0 (compatible; MSIE 6.0; X11; Linux i686; ja) Opera 10.10',
     ie => 'not IE but true'},
    {value => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'},
    {value => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.52.7 (KHTML, like Gecko) Version/5.1.2 Safari/534.52.7'},
    {value => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30'},
    {value => 'Mozilla/5.0 (iPhone; U; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9A334 Safari/7534.48.3',
     iphone => 1},
    {value => 'Mozilla/5.0 (iPod; U; CPU iPhone OS 4_3_5 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8L1 Safari/6533.18.5',
     iphone => 1},
    {value => 'Mozilla/5.0 (iPad; U; CPU OS 4_3_2 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5',
     ipad => 1},
    {value => 'Mozilla/5.0 (Linux; U; Android 2.3.3; ja-jp; INFOBAR A01 Build/S9081) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1',
     android => 1},
    {value => 'Opera/9.80 (Android 2.3.3; Linux; Opera Mobi/ADR-1111101157; U; ja) Presto/2.9.201 Version/11.50',
     android => 1},
    {value => 'Opera/9.80 (Android 3.2.1; Linux; Opera Tablet/ADR-1109081720; U; ja) Presto/2.8.149 Version/11.10',
     android => 1},
    {value => 'Mozilla/5.0 (Android; Linux armv7l; rv:9.0) Gecko/20111216 Firefox/9.0 Fennec/9.0',
     android => 1},
    {value => 'DoCoMo/1.0/D253i/c10/TB/W17H09',
     docomo => 1, docomo1 => 1, galapagos => 1},
    {value => 'DoCoMo/2.0 SH903i(c100;TB;W20H13)', 
     docomo => 1, docomo1 => 1, galapagos => 1},
    {value => 'DoCoMo/2.0 P03B(c500;TB;W53H11)',
     docomo => 1, galapagos => 1},
    {value => 'DoCoMo/2.0 P09A3(c500;SD)',
     docomo => 1, galapagos => 1},
    {value => 'DoCoMo/2.0 SH02C(c500;TB;W30H13)',
     docomo => 1, galapagos => 1},
    {value => 'Mozilla/4.08 (SH903i;FOMA;c300;TB)'}, # Full browser
    {value => 'KDDI-SA31 UP.Browser/6.2.0.7.3.129 (GUI) MMP/2.0',
     au => 1, galapagos => 1},
    {value => 'KDDI-XX99 UP.Browser/6.2_7.2.7.1.K.8.400 (GUI) MMP/2.0',
     au => 1, galapagos => 1},
    {value => 'Mozilla/4.0(compatible;MSIE6.0; KDDI-CA37) Opera 8.60 [ja]'}, # Full browser
    {value => 'Vodafone/1.0/V905SH/SHJ001[/Serial] Browser/VF-NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1',
     softbank => 1, galapagos => 1},
    {value => 'SoftBank/2.0/004SH/SHJ001[/Serial] Browser/NetFront/3.5 Profile/MIDP-2.0 Configuration/CLDC-1.1',
     softbank => 1, galapagos => 1},
    {value => 'Mozilla/5.0 (832SHs;SoftBank[;Serial]) NetFront/3.5'}, # Full browser
    {value => 'Opera/9.30 (Nintendo Wii; U; ; 3642; de)',
     wii => 1},
    {value => 'Mozilla/4.0 (compatible; MSIE 6.0; Nitro) Opera 8.50 [ja]',
     ie => 1}, # DS browser
    {value => 'Opera/9.50 (Nintendo DSi; Opera/446; U; ja)',
     dsi => 1, ds => 1},
    {value => 'Mozilla/5.0 (Nintendo 3DS; U; ; ja) Version/1.7412.JP',
     '3ds' => 1, ds => 1},
    {value => 'Mozilla/4.0 (PSP (PlayStation Portable); 2.00)',
     psp => 1},
    {value => 'Mozilla/5.0 (PLAYSTATION 3; 1.00)', ps3 => 1},
    {value => 'Mozilla/5.0 (PlayStation Vita 1.50) AppleWebKit/531.22.8(KHTML, like Gecko) Silk/3.2',
     psvita => 1},
    {value => 'Opera/9.80 (J2ME/MIDP; Opera Mini/5.0.0176/1150; U; ja) Presto/2.4.15'},
    {value => 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
     bot => 1},
    {value => 'Googlebot-Image/1.0',
     bot => 1},
    {value => 'DoCoMo/2.0 N905i(c100;TB;W24H16) (compatible; Googlebot-Mobile/2.1; +http://www.google.com/bot.html)',
     bot => 1, docomo1 => 1, docomo => 1, galapagos => 1},
    {value => 'msnbot/1.0 (+http://search.msn.com/msnbot.htm)', bot => 1},
    {value => 'Y!J-BSC/1.0 (http://help.yahoo.co.jp/help/jp/blog-search/)',
     bot => 1},
    {value => 'Y!J-SRD/1.0', bot => 1, galapagos => 1},
    {value => 'Y!J-MBS/1.0', bot => 1, galapagos => 1},
    {value => 'KDDI-CA23 UP.Browser/6.2.0.5 (compatible; Y!J-SRD/1.0; http://help.yahoo.co.jp/help/jp/search/indexing/indexing-27.html)',
     bot => 1, galapagos => 1, au => 1},
    {value => 'Mozilla/5.0 (compatible; Yahoo! Slurp China; http://misc.yahoo.com.cn/help.html)',
     bot => 1},
    {value => 'Baiduspider+(+http://www.baidu.jp/spider/)', bot => 1},
    {value => 'Yeti/1.0 (NHN Corp.; http://help.naver.com/robots/)', bot => 1},
    {value => 'Hatena Star UserAgent', bot => 1, hatena_star => 1},
    {value => 'Hatena Star UserAgent/2', bot => 1, hatena_star => 1},
  ) {
    my $ua = Wanage::HTTP::UA->new_from_http_user_agent ($test->{value});
    for (qw(ie iphone ipad android docomo1 docomo softbank au galapagos
            ds dsi 3ds wii ps3 psp psvita hatena_star bot)) {
      my $key = 'is_' . $_;
      is_bool $ua->$key, $test->{$_},
          "@{[$test->{value} || '']} $key";
    }
  }
} # _is_ua

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
