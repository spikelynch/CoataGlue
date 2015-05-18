#!/usr/bin/perl

=head1 NAME

201_omeka_xml.t

=head1 DESCRIPTION

Tests an XML::SAX parser for Omeka's native XML format

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 10;
use Data::Dumper;
use Log::Log4perl;

use Net::OAI::Harvester;

use CoataGlue::Converter::OAIPMH::Omeka_XML;

my %ITEM_TYPES = (
    'Collective noun' => 1,
    'Hyperlink' => 3,
    'Oral History' => 110,
    'Organisation' => 3,
    'Person' => 4,
    'Species' => 39,
    'Still Image' => 44,
    'Study Region' => 13
    );


my $LOG4J = "$Bin/log4j.properties";
my $LOGGER = "CoataGlue.tests.201_omeka_xml.t";

Log::Log4perl->init($LOG4J);

my $log = Log::Log4perl->get_logger($LOGGER);




my $OAIPMHURL = 'http://dharmae.research.uts.edu.au/oai-pmh-repository/request';

my $harvester = Net::OAI::Harvester->new(
    baseURL => $OAIPMHURL
    );


my $records = undef;
eval {
    $records = $harvester->listAllRecords(
        metadataPrefix => 'omeka-xml',
        metadataHandler => 'CoataGlue::Converter::OAIPMH::Omeka_XML'
        );
};

diag("Warning - the species and region counts in this test are hard coded");

if( $@ ) {
    die("OAI-PMH harvest failed: $@");
} else {
    ok($records, "Harvested OAI-PMH");

    my @datasets = ();

    while ( my $record = $records->next() ) {
        my $md = $record->metadata->{md};
        push @datasets, $md;
        print "$md->{itemType}->[0]: $md->{item}{Title}->[0]\n";
        if( $md->{tags} ) {
            print "Tags = " . join(',', @{$md->{tags}}) . "\n";
        }
    }

    ok(@datasets, "Got datasets");

    my %count = ();
    
    for my $type ( sort keys %ITEM_TYPES ) {
        $count{$type} = scalar grep { $_->{itemType}->[0] eq $type } @datasets;
        cmp_ok( $count{$type} , '==', $ITEM_TYPES{$type}, "Got $ITEM_TYPES{$type} of $type");
    }
    
}

sub unwrap {
    my ( $aref ) = @_;

    if( ref($aref) eq 'ARRAY' ) {
        return join(', ', @$aref);
    } else {
        return '-';
    }
}





