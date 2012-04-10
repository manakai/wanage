package Warabe::App::Role::MessagePack;
use strict;
use warnings;
use Data::MessagePack;

sub mp_param {
    my $value = $_[0]->bare_param ($_[1]);
    if (defined $value) {
        return eval { Data::MessagePack->new->decode($value) };
    } else {
        return undef;
    }
}

1;
