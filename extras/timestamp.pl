#!/usr/bin/perl

use strict;
use POSIX qw(strftime);

print strftime("%FT%T%z", localtime) . "\n";


print strftime("%+", localtime) . "\n";
