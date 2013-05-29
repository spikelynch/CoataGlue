#!/usr/bin/perl

use strict;

use XML::RegExp;


my @NAMES = (
	'000',
	'hi.there',
	'this:has:colon',
	'how_about_underscores',
	'justaword',
	'what about spaces',
	'orquestionmarks?',
	'OrdinaryFile.png'
	
);

for my $name ( @NAMES ) {
	if( $name =~ /^$XML::RegExp::NCName$/ ) {
		print "$name is OK\n";
	} else {
		print "$name is bad\n";
	}
}