package CoataGlue::Converter::Omeka;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use Net::OAI::Harvester;

my @MANDATORY_FIELDS =  qw(url);

=head1 NAME

CoataGlue::Converter::Omeka

=head1 DESCRIPTION

Fetches 

=head1 METHODS

=over 4

=item init(%params)

Parameters (from DataSource.cf):

=over 4

=item url: Omeka endpoint

=back

=cut


sub init {
    my ( $self, %params ) = @_;
	
    $self->{twig} = XML::Twig->new();	
    
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

        $self->{harvester} = Net::OAI::Harvester->new(
            baseURL => $self->{url}
            );

        
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
        warn("OAI-PMH harvest failed: $@");
        return ();
    }
    

    while ( my $record = $records->next() ) {
        my $header = $record->header();
        my $metadata = $record->metadata();
        print "Identifier: " . $header->identifier() . "\n";
        print "Title     : " . $metadata->title();
        print "\n\n";
    }

    return (); #@datasets ;
}


=item parse_metadata(path => $path, shortpath => $shortpath [, basedir => $basedir ])
    
    Parse a metadata file, returns a hashref with:
    
{
    file => $path,
    location => $path,
    metadata => $md,
    datastreams => $datastreams
}


=cut
    
    
    sub parse_metadata {
	my ( $self, %params ) = @_;
	
	my $path = $params{path};
	my $shortpath = $params{shortpath};
        my $basedir = $params{basedir} || $self->{basedir};
        
	my $tw;
	
	eval {
            $tw = $self->{twig}->parsefile($path);
	};
	
	if( $@ ) {
            $self->{log}->error("XML parse error on $path: $@");
            $self->{twig} = undef;
            $self->{twig} = XML::Twig->new();
            return undef;
	}
	
	# Treat all children of the root element as metadata fields.
	# If there are more than one, store as an arrayref
	
	my $md = {};
        
        my $md_elt;
        
        $self->{log}->trace("metadata tag = $self->{metadatatag}");
        
        if( $self->{metadatatag} ) {
            ( $md_elt ) = $tw->root->descendants($self->{metadatatag});
            if( !$md_elt ) {
                $self->{log}->error("Tag $self->{metadatatag} not found");
                return undef;
            }
        } else {
            $md_elt = $tw->root;
        }
        
	for my $elt ( $md_elt->children ) {
            my $tag = $elt->tag;
            if( $md->{$tag} ) {
                if( !ref($md->{$tag}) ) {
                    $md->{$tag} = [ $md->{$tag} ];
                }
                push @{$md->{$tag}}, $elt->text;
            } else {
                $md->{$tag} = $elt->text;
            }
	}
        
	my $datastreams = {};
	
	if( !$md->{$self->{datastreams}} ) {
            $self->{log}->error("No datastreams found in <$self->{datastreams}>");
	} else {
            my $ds = $md->{$self->{datastreams}};
            $self->{log}->trace("Datastreams = $ds");
            if( !ref($ds) ) {
                if( $self->{datastream_delimiter} ) {
                    $ds = [ split(/$self->{datastream_delimiter}/, $ds) ];
                } else {
                    $ds = [ $ds ];
                }
            }
            
        # for now, we treat file://  and /sdsda/asdas as though they
        # were relative to basedir.  For this class, basedir is a global
        # class setting, but subclasses can override it on a dataset-by-
        # dataset basis (ie a user/job directory for Osiris)

            for my $file ( @$ds ) {
                if( $file =~ /^http/ ) {
                    $self->{log}->warn("$self can only handle files, not http");
                } else {
                    $file =~ s#^file://##;   # remove file://
                    $file = $basedir . $file;
                    $self->{log}->trace("Datastream file = $file");
                    if( -f $file ) {
                        my ( $mimetype, $encoding ) = $self->mime_type(file => $file);
                        
                        $datastreams->{$file} = {
                            id => $file,
                            original => $file,
                            mimetype => $mimetype
                        };
                    } else {
                        $self->{log}->error("Datastream $file not found");
                    }
                }
            }
	}
        
	$md->{dateconverted} = $self->timestamp;
        
        $self->{log}->trace(Dumper({ datastreams => $datastreams }));
	
	return {
            file => $path,
            location => $path,
            metadata => $md,
            datastreams => $datastreams
	};
}


=back

=cut


1;
