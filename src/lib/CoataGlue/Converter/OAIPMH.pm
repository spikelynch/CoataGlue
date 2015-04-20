package CoataGlue::Converter::OAIPMH;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use Net::OAI::Harvester;

my @MANDATORY_FIELDS =  qw(basedir url);

=head1 NAME

CoataGlue::Converter::OAIPMH

=head1 DESCRIPTION

Gets metadata from an OAI-PMH harvester, and optionally downloads datastreams
and ingests them as well.

=head1 METHODS

=over 4

=item init(%params)

Parameters (from DataSource.cf):

=over 4

=item url: OAI-PMH endpoint
=item metadata_prefix: metadata format (default is oai_dc)
=item fetch: (optional) metadata field containing download URLs
=item pattern: (optional) re to select which fetch fields to download 
=item basedir: (optional) base directory to download files

=back

Note that fetch, pattern and basedir are all optional, but if basedir is
present, then there has to be a value for fetch.  If there is no value for
pattern, then the converter will try to download everything it finds in
the fetch elements.

=cut


sub init {
    my ( $self, %params ) = @_;
	
    for my $field ( keys %params ) {
        $self->{$field} = $params{$field};
    }
    
    my $invalid = 0;
    
    for my $field ( @MANDATORY_FIELDS ) {
        if( !$self->{$field} ) {
            $self->{log}->error("Missing field $field");
            $invalid = 1;
        }
    }

    $self->{metadata_prefix} ||= $DEFAULT_METADATA;

    if( $self->{fetch} ) {
        if( ! $self->{basedir} ) {
            $self->{log}->error("Error: 'fetch' is set, but 'basedir' is not");
            $invalid = 1;
        }
    }
    
    if( $invalid ) {
        $self->{log}->debug("Called from " . join(":", caller));
        return undef;
    } else {
        my %oai_params = { baseURL => $self->{url} };
        if( $self->{dump} ) {
            $oai_params{dumpDir} = $self->{dump};
        }
        $self->{harvester} = Net::OAI::Harvester->new(%oai_params);
        
        return $self;
    }
}



=item scan()
    
Scans datasets from the OAI-PMH feed, downloading them if the fetch
parameter has been set
    
=cut
    

sub scan {
    my ( $self, %params ) = @_;
    
    my $records = undef;
    eval {
        $records = $self->{harvester}->listRecords(
            metadataPrefix => 'oai_dc'
            );
    };

    if( $@ ) {
        $self->{log}->error("OAI-PMH harvest failed: $@");
        return ();
    }

    my @datasets = ();

    $self->{log}->trace("Iterating over records: $records");
    while ( my $record = $records->next() ) {
        my $dataset = $self->fetch_record(record => $record);
        push @datasets, $dataset
    }

    return @datasets ;
}


=item fetch_record(record => $record)

Reads the metadata from an OAI-PMH record and downloads files if possible    
    
{
    file => $path,
    location => $path,
    metadata => $md,
    datastreams => $datastreams
}


=cut
    
sub fetch_record    


=back

=cut


1;
