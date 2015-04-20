package CoataGlue::Converter::Omeka;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use Net::OAI::Harvester;

my @MANDATORY_FIELDS =  qw(basedir omekaurl);

=head1 NAME

CoataGlue::Converter::Omeka

=head1 DESCRIPTION

Fetches 

=head1 METHODS

=over 4

=item init(%params)

Parameters (from DataSource.cf):

=over 4

=item omekaurl: Omeka instance
=item basedir: base directory to download files

=back

=cut


sub init {
    my ( $self, %params ) = @_;
	
    for my $field ( keys %params ) {
        $self->{$field} = $params{$field};
    }
    
    my $missing = 0;
    
    for my $field ( @MANDATORY_FIELDS ) {
        if( !$self->{$field} ) {
            $self->{log}->error("Missing field $field");
            $missing = 1;
        }
        
    }

    $self->{log}->error("Called from " . join(":", caller));
    
    if( $missing ) {
        return undef;
    } else {
        $self->{oai} = $self->{omekaurl} . '/'
        if( $self->{dump} ) {
            $self->{harvester} = Net::OAI::Harvester->new(
                baseURL => $self->{omekaurl},
                dumpDir => $self->{dump}
                );
        } else {
            $self->{harvester} = Net::OAI::Harvester->new(
                baseURL => $self->{url}
                );
        }

        
        return $self;
    }
}



=item scan()
    
Scans and returns Datasets
    
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
