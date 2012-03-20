use strict;
use warnings;
use File::Basename;

my $file_name = dirname (__FILE__) . '/../config/perl/libs.txt';
if (-f $file_name) {
  open my $file, '<', $file_name or die "$0: $file_name: $!";
  unshift @INC, split /:/, <$file>;
}

require Path::Class;
my $root_d = Path::Class::file (__FILE__)->dir->resolve->parent;

unshift @INC,
    $root_d->subdir ('lib')->stringify,
    glob $root_d->subdir ('modules', '*', 'lib')->stringify;

1;

## License: Public Domain.
