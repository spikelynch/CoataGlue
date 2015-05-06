package CoataGlue::Converter::OAIPMH;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use Net::OAI::Harvester;
use File::Fetch;


my @MANDATORY_FIELDS =  qw(url id_re);

my $DEFAULT_METADATA = 'oai_dc';

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
=item id_re: re matching the identifier to use as this dataset's item id 
=item metadata_prefix: metadata format (default is oai_dc)
=item files: (optional) metadata field containing download URLs
=item files_re: (mandatory if 'files' is set) re to select which identifiers to download
=item basedir: (mandatory if 'files' is set) base directory in which to download files
=item dump: (optional) directory in which to dump raw OAI records

=back

Note that files, files_re and basedir are all optional, but if files is 
present files_re and basedir must also be present

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

    if( $self->{files} ) {
        if( ! $self->{basedir} ) {
            $self->{log}->error("Error: 'files' is set, but 'basedir' is not");
            $invalid = 1;
        }
        if( ! $self->{files_re} ) {
            $self->{log}->error("Error: 'files' is set, but 'files_re' is not");
            $invalid = 1;
        }
    }
    
    if( $invalid ) {
        $self->{log}->debug("Called from " . join(":", caller));
        return undef;
    } else {
        my %oai_params = ( baseURL => $self->{url} );
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
        $records = $self->{harvester}->listAllRecords(
            metadataPrefix => $self->{metadata_prefix}
            );
    };

    if( $@ ) {
        $self->{log}->error("OAI-PMH harvest failed: $@");
        return ();
    }

    my @datasets = ();

    $self->{log}->trace("I am a $self");

    $self->{log}->trace("Iterating over records: $records");

    while ( my $record = $records->next() ) {
        if( my $dataset = $self->read_dataset(record => $record ) ) {
            push @datasets, $dataset
        }
    }

    return @datasets;
}


=item read_dataset(record => $record)

Reads the metadata from an OAI-PMH record and downloads files if required

Net::OAI::Header methods:

=over 4

=item status

=item identifier

=item datestamp

=item sets

=back

=cut

sub read_dataset {
    my ( $self, %params ) = @_;

    my $record = $params{record};

    my $header = $record->header;
    my $metadata = $record->metadata;

    print Dumper({ "metadata $metadata" => $metadata}) . "\n";

    die;
    
    my $id = $header->identifier;
    my $date = $header->datestamp;
    my $status = $header->status;
    my $sets = $header->sets;

    $self->{log}->info("id = $id");
    $self->{log}->info("datestamp = $date");

    my $url = $self->get_item_url(
        id => $id,
        values => $metadata->{identifier}
        );

    return undef unless $url;

    my @files = ();
    my $datastreams = {};
    
    if( $self->{files} ) {
        if( exists $metadata->{$self->{files}} ) {
            my $file_idents = $metadata->{$self->{files}};
            @files = $self->get_file_urls(
                id => $id, 
                values => $file_idents
                );
            $self->{log}->info("$id has file urls " . join(', ', @files));
            $datastreams = $self->fetch_files(
                id => $id,
                files => \@files
                );
        } else {
            $self->{log}->warn("Item $id has no $self->{files} metadata field to get file URLs from");
        }
    }

    my $files = {};

    $metadata->{dateconverted} = $self->timestamp;
    
    my $dataset = $self->{source}->dataset(
        metadata => $metadata,
        location => $url,
        file => $url,
        datastreams => $datastreams
        
        );
    
}


sub get_item_url {
    my ( $self, %params ) = @_;

    my $values = $params{values};
    my $id = $params{id};

    my @urls = $self->filter_re(
        values => $values,
        re => $self->{id_re}
        );
    if( !@urls ) {
        $self->{log}->error("Item $id: couldn't find identifier matching $self->{id_re}");
        return undef;
    }

    if( @urls > 1 ) {
        $self->{log}->warn("Item $id has more than one identifier matching $self->{id_re}: using $urls[0]");
    }

    return $urls[0];
}


sub get_file_urls {
    my ( $self, %params ) = @_;

    my $values = $params{values};
    my $id = $params{id};
    
    my @urls = $self->filter_re(
        values => $values,
        re => $self->{files_re}
        );

    if( !@urls ) {
        $self->{log}->warn("Item $id has no files");
    }

    return @urls;
}

 
sub filter_re {
    my ( $self, %params ) = @_;

    my $re = $params{re};
    my $values = $params{values};

    if( ref($values) ne 'ARRAY' ) {
        $self->warn("Empty or non-array-ref value passed to filter_re");
        return ();
    }

    return grep /$re/, @$values;
}


sub fetch_files {
    my ( $self, %params ) = @_;

    my $id = $params{id};
    my $files = $params{files};

    my $path = join('/', $self->{basedir}, $id);

    if( -d $path ) {
        $self->{log}->warn("Item $id directory $path already exists");
    } else {
        mkdir $path || do {
            $self->{log}->error("Item $id - couldn't create path $path");
            return undef;
        };
    }

    my $ds = {};

    for my $uri ( @$files ) {
        my $ff = File::Fetch->new(uri => $uri);
        my $filepath = $ff->fetch(to => $path);
        if( $filepath ) {
            my $mimetype = $self->mime_type(file => $filepath);
            $ds->{$uri} = {
                id => $uri,
                original => $filepath,
                mimetype => $mimetype
            };
            $self->{log}->debug("Item $id downloaded $uri to $filepath");
        } else {
            $self->{log}->error("Item $id - download of $uri failed: " . $ff->error);
        }
    }
    return $ds;
}

1;
