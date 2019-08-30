#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

use Imager;

my $data;

while (my $line = <STDIN>) {
    chomp $line;
    my @fields = split ';', $line;
    for my $field (@fields) {
        if ($field =~ /^\$([^=]+)=([^=]+)/) {
            my $key  = $1;
            my $val  = $2;
            die "duplicate key $key\n"
                if (defined $data->{$key});
            $data->{$key} = $val;
        }
        else {
            die "Failed to parse field $field\n";
        }
    }
}

# extract image dimensions
die "Missing IMAGE_SIZE key\n"
    if (! defined $data->{IMAGE_SIZE});
my @dims = split 'x', $data->{IMAGE_SIZE};
die "Failed to parse image size $data->{IMAGE_SIZE}\n"
    if (scalar(@dims) != 2);
my $n_cols = $dims[0];
my $n_rows = $dims[1];

# unpack mask string into matrix, the slow way
# this could almost certainly be optimized if necesssary
die "Missing DATA key\n"
    if (! defined $data->{DATA});
my @vals = split '', $data->{DATA};
die "Data string length mismatch with dimension specification\n"
    if (scalar(@vals) != $n_cols * $n_rows);
die "Empty data string!\n"
    if (! scalar @vals);

my @x_on;
my @y_on;

for my $i (0..$#vals) {
    next if ($vals[$i] eq 'N'); # skip 'off' pixels
    my $col = $i % $n_cols;
    my $row = int($i/($n_cols));
    push @x_on, $col;
    push @y_on, $row;
}

my $white = Imager::Color->new(255);
my $img = Imager->new(
    xsize=>$n_cols,
    ysize=>$n_rows,
    channels=>1,
);
$img->setpixel(
    x     => \@x_on,
    y     => \@y_on,
    color => $white,
);
$img->write(
    fh   => \*STDOUT,
    type => 'png',
);
