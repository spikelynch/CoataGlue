package CoataGlue::Converter::OAIPMH;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use Net::OAI::Harvester;
use CoataGlue::Converter::OAIPMH::Omeka_XML;
use File::Fetch;


my @MANDATORY_FIELDS =  qw(url item_url);

my @OMEKA_ITEM_FIELDS = (
    'Title',
    'CollectionTitle',
    'Creator',
    'Date',
    'Description',
    'Access Rights',
    'Spatial Coverage'
    );

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
=item item_url: Omeka item endpoint
=item metadata_prefix: metadata format (default is oai_dc)
=item metadata_handler: metadata XML::SAX handler, mandatory if a metadata_prefix other than oai_dc is set
=item filter: a metadata field and a regexp (optional)
=item files: (optional) base directory in which to download files
=item dump: (optional) directory in which to dump raw OAI records

=back



=cut


sub init {
    my ( $self, %params ) = @_;
	
    for my $field ( keys %params ) {
        $self->{$field} = $params{$field};
    }
    
    my $invalid = 0;
    
    for my $field ( @MANDATORY_FIELDS ) {
        if( !$self->{$field} ) {
            $self->{log}->error("Missing field: '$field'");
            $invalid = 1;
        }
    }

    if( $self->{filter} ) {
        my ( $field, $re ) = split(/ /, $self->{filter});
        $self->{filter} = [ $field, qr/$re/o ];
    }

    if( $self->{metadata_prefix} ) {
        if( !$self->{metadata_handler} ) {
            $self->{log}->error("Error: metadata_prefix needs a metadata_handler");
            $invalid = 1;
        }
        $self->{hparams} = {
            metadataPrefix => $self->{metadata_prefix},
            metadataHandler => $self->{metadata_handler}
        };
    } else {
        $self->{metadata_prefix} = $DEFAULT_METADATA;
        $self->{hparams} = {
            metadataPrefix => $self->{metadata_prefix}
        };
    }
    
    if( $invalid ) {
        $self->{log}->debug("Called from " . join(":", caller));
        return undef;
    } else {
        my %oai_params = (
            baseURL => $self->{url}
            );
        if( $self->{dump} ) {
            $oai_params{dumpDir} = $self->{dump};
        }
        $self->{harvester} = Net::OAI::Harvester->new(%oai_params);
        
        return $self;
    }
}



=item scan()
    
Scans datasets from the OAI-PMH feed.

=cut
    

sub scan {
    my ( $self, %params ) = @_;
    
    my $records = undef;
    eval {
        $records = $self->{harvester}->listAllRecords(%{$self->{hparams}});
    };

    if( $@ ) {
        $self->{log}->error("OAI-PMH harvest failed: $@");
        return ();
    }

    my @datasets = ();


    while ( my $record = $records->next() ) {
        if( my $dataset = $self->read_dataset(record => $record ) ) {
            if( $dataset ) {
                push @datasets, $dataset
            }
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
    my $md = $record->metadata->{md};

    if( $self->{filter} ) {
        if( $md->{$self->{filter}[0]}[0] !~ /$self->{filter}[1]/ ) {
            $self->{log}->warn("Skipping record $md->{item}{itemID}: $self->{filter}[0] = $md->{$self->{filter}[0]}[0]");
            return undef;
        }
    }
    
    my $id = $header->identifier;
    my $date = $header->datestamp;
    my $status = $header->status;
    my $sets = $header->sets;

    $self->{log}->info("id = $id");
    $self->{log}->info("datestamp = $date");

    my $metadata = {
        dateconverted => $self->timestamp,
    };

    my $item = $md->{item};

    for my $field ( @OMEKA_ITEM_FIELDS ) {
        my $cvt_field = lc($field);
        $cvt_field =~ s/\s/_/;
        if( $item->{$field} && ref($item->{$field}) eq 'ARRAY' ) {
            $metadata->{$cvt_field} = join(' ', @{$item->{$field}});
        } else {
            $metadata->{$cvt_field} = '';
        }
    }

    if( $md->{tags} && ref($md->{tags}) eq 'ARRAY' ) {
        $metadata->{tags} = join(' ', @{$md->{tags}});
    }

    my $url = join('', $self->{item_url}, $md->{itemID});

    my $datastreams = {};
    
    if( $md->{files} ) {
        for my $id ( keys %{$md->{files}} ) {
            my ( $mimetype, $encoding ) = $self->mime_type(file => $md->{files}{$id}{src});
            $datastreams->{$id} = {
                id => $id,
                original => $md->{files}{$id}{src},
                mimetype => $mimetype
            };
        }
    }
    
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
