#!/usr/bin/perl

=head1 NAME

008_encrypt_staff_ids.t

=head1 DESCRIPTION

Test the staff_id => handle encryption

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 5;
use Data::Dumper;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Converter;
use CoataGlue::Dataset;
use CoataGlue::Person;
use CoataGlue::Test qw(setup_tests);


# my %STAFF_IDS = (
# 	910031 => 'b14e8cdc',
# 	105465 => 'aac499d9',
# 	890007 => 'b1e5f066'
# );

my %STAFF_IDS = (
    398502 => '7ad2110d',
    943004 => 'b8453bc8',
    '032492' => 'bf62712a'
    );


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.102_encrypt_staff_ids";
Log::Log4perl->init($LOG4J);
my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $cg = CoataGlue->new(%{$fixtures->{LOCATIONS}});

ok($cg, "Initialised CoataGlue object");

my @sources = $cg->sources;

ok(@sources, "Got source");

my $source = $sources[0];

my $prefix;

if( $cg->conf('Redbox', 'staffhandle') eq 'none' ) {
    $prefix = '';
} else {
    $prefix = $cg->conf('General', 'handles' ) 
        . $cg->conf('Redbox', 'staffhandle');
}
for my $id ( keys %STAFF_IDS ) {
	my $expect = $prefix . $STAFF_IDS{$id};
	my $got = $source->staff_id_to_handle(id => $id);
	cmp_ok($got, 'eq', $expect, "id $id => $expect"); 
}

