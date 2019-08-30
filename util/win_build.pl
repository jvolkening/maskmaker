#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

use File::Path qw/rmtree/;

# need 'pp' installed
require PAR::Packer;

my $ret = system("pp -o maskmaker.exe -x --xargs=\"--config files/millichip.xml --out foobar\" maskmaker");
if ($ret) {
    die "ERROR: packaging failed: $!\n";
}
rmtree('foobar');
