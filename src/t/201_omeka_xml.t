#!/usr/bin/perl

=head1 NAME

201_omeka_xml.t

=head1 DESCRIPTION

Tests an XML::SAX parser for Omeka's native XML format

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 1;
use Data::Dumper;

use Net::OAI::Harvester;

use CoataGlue::Converter::OAIPMH::Omeka_XML;

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

if( $@ ) {
    die("OAI-PMH harvest failed: $@");
} else {
    ok(@$records > 0, "Got " . scalar(@$records) . " omeka records");
    
    my $csv = Text::CSV->new({eol => "\n"}) || die;
    my $fh;
    open $fh, ">:encoding(utf8)", "dump.csv" or die("Couldn't open $!");

    while ( my $record = $records->next() ) {
        my $header = $record->header;
        my $metadata = $record->metadata;
        my $md = $metadata->{md};

        $csv->print($fh, [
                        unwrap($md->{itemType}),
                        $md->{itemTypeID},
                        unwrap($md->{item}{Title}),
                        unwrap($md->{item}{Description}),
                        unwrap($md->{item}{'Spatial Coverage'}),
                        unwrap($md->{item}{License}),
                        unwrap($md->{item}{Creator})
                    ]);
    }
    close $fh;
    
}

sub unwrap {
    my ( $aref ) = @_;

    if( ref($aref) eq 'ARRAY' ) {
        return join(', ', @$aref);
    } else {
        return '-';
    }
}





