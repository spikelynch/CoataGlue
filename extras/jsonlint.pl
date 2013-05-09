#!/usr/bin/perl

use strict;

use JSON;
use Data::Dumper;

local $/ = undef;

my $json = <>;

my $data = decode_json($json);

print Dumper($data);
