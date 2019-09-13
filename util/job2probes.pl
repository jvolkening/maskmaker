#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

use Cwd qw/getcwd abs_path/;
use File::Basename qw/basename dirname/;
use File::Temp;
use Imager;
use XML::Simple qw/:strict/;

my $jobfile = $ARGV[0];
my $rel_path = abs_path( dirname( $jobfile ) );

my $job = XMLin(
    $jobfile,
    ForceArray => [qw/
        LoadImplementation
        Cycle
        DMDMask
        DMDEncodePos
        BitEncodeMirror
    /],
    KeyAttr    => {},
);

my @proj_paths;

my $cwd = abs_path(getcwd());
my @zips = map {abs_path("$rel_path/$_->{path}")} @{ $job->{MaskLoad}->{LoadImplementation}};
for my $fn (@zips) {
    say STDERR "Unzipping $fn";
    die "Missing zip file $fn\n"
        if (! -e $fn);
    my $tmp = File::Temp->newdir(UNLINK => 1);
    chdir $tmp;
    my $ret = system(
        'unzip',
        $fn,
    );
    die "Error unzipping $fn: $1\n"
        if ($ret);
    push @proj_paths, $tmp; 
    chdir $cwd;
}

my @matrices;

my @cycles = @{ $job->{Sequence}->{Cycle} };
die "No cycles found\n"
    if (scalar @cycles < 1);
for my $i (0..$#cycles) {
    say STDERR "Parsing cycle $i\n";
    my $cycle = $cycles[$i];
    die "Cycle $i out of order\n"
        if ($i + 1 != $cycle->{index});
    my $base = $cycle->{Coupling}->{Base}
        // die "Missing base for cycle $i\n";
    if (defined $cycle->{Exposure}) {
        for my $mask (@{ $cycle->{Exposure}->{DMDMask} }) {
            my $fn  = $mask->{MaskBitmap};
            next if (basename($fn) eq 'WhiteT.msk');
            my $pos = $mask->{position} - 1;
            my $fn_full = join '/',
                $proj_paths[$pos],
                $fn,
            ;
            die "Missing mask $fn_full\n"
                if (! -e $fn_full);
            my ($xs, $ys) = parse_msk($fn_full);
            for (0..$#$xs) {
                my $x = $xs->[$_];
                my $y = $ys->[$_];
                $matrices[$pos]->{$x}->{$y} .= $base;
            }
        }
    }
}

for my $m (0..$#matrices) {
    for my $x (sort {$a <=> $b} keys %{ $matrices[$m] }) {
        for my $y (sort {$a <=> $b} keys %{ $matrices[$m]->{$x} }) {
            my $probe = reverse $matrices[$m]->{$x}->{$y};
            say join "\t",
                $m,
                $x,
                $y,
                $probe,
            ;
        }
    }
}

sub parse_msk {

    my ($fn) = @_;

    my $data;
    open my $in, '<', $fn;
    while (my $line = <$in>) {
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

    #for my $i (0..$#vals) {
        #next if ($vals[$i] eq 'N'); # skip 'off' pixels
        #my $col = $i % $n_cols;
        #my $row = int($i/($n_cols));
        #push @x_on, $col;
        #push @y_on, $row;
    #}
    my @on = grep {$vals[$_] ne 'N'} (0..$#vals);
    @x_on = map {$_ % $n_cols} @on;
    @y_on = map {int($_/$n_cols)} @on;

    return (\@x_on, \@y_on);

}
