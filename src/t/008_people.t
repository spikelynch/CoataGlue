#!/usr/bin/perl

=head1 NAME

008_people.t

=head1 DESCRIPTION

Test the CoataGlue::People->lookup( ) method

=cut

use strict;

if( ! $ENV{COATAGLUE_PERLLIB} || ! $ENV{COATAGLUE_LOG4J}) {
	die("One or more missing environment variables.\nRun perldoc $0 for more info.\n");
}

use lib $ENV{COATAGLUE_PERLLIB};


use Test::More tests => 9;
use Data::Dumper;
use XML::Twig;
use Text::Diff;


use CoataGlue;
use CoataGlue::Source;
use CoataGlue::Person;
use CoataGlue::Test qw(setup_tests);

my %RESEARCHER = (
    id => '040221',
    familyname => 'Leijdekkers',
    givenname => 'Peter',
    honorific => 'Doctor',
    jobtitle => 'Senior Lecturer',
    groupid => '927'
    );



my $LOGGER = "CoataGlue.tests.008_people";

if( !$ENV{COATAGLUE_LOG4J} ) {
	die("Need to set COATAGLUE_LOG4J to point at a Log4j config file");
}

Log::Log4perl->init($ENV{COATAGLUE_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

my $fixtures = setup_tests(log => $log);

my $CoataGlue = CoataGlue->new(
	global => $ENV{COATAGLUE_CONFIG},
	sources => $ENV{COATAGLUE_SOURCES},
	templates => $ENV{COATAGLUE_TEMPLATES}
);

ok($CoataGlue, "Initialised CoataGlue object");


my $solr = $CoataGlue->mint;

ok($solr, "Initialised Apache::Solr object");

my $key = $CoataGlue->conf('Redbox', 'cryptkey');
my $id = $RESEARCHER{id};

my $person = CoataGlue::Person->lookup(
    coataglue => $CoataGlue,
    id => $id,
    prefix => ''
    );

ok($person, "Person lookup $id returned a result");

for my $field ( sort keys %RESEARCHER ) {
    cmp_ok($person->{$field}, 'eq', $RESEARCHER{$field}, "Got $field = $RESEARCHER{$field}");
}

