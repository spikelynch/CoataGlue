package CoataGlue::Converter::XML;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;

my @MANDATORY_FIELDS =  qw(basedir metadatafile datastreams);

=head1 NAME

CoataGlue::Converter::XML

=head1 DESCRIPTION

Generic converter for XML metadata.

=head1 METHODS

=over 4

=item init(%params)

Parameters (from DataSource.cf):

=over 4

=item basedir: directory to scan for XML documents
=item metadatafile: pattern to match metadata XML files
=item datastreams: XML tag in which files of datastreams are stored

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

	if( $missing ) {
		return undef;
	} else {
		return $self;
	}
}



=item scan()

Scans basedir and returns Datasets

=cut


sub scan {
	my ( $self, %params ) = @_;
	
	my $basedir = $self->{basedir};
	
	if( ! -d $basedir ) {
		$self->{log}->error("$basedir is not a directory");
		die;
	}
	
	opendir(my $dh, $basedir) || do {
		$self->error("Can't open $basedir: $!");
		return undef;
	};
	
	my @datasets = ();
    my $required = $self->{required} || undef;
	
	ITEM: for my $item ( readdir($dh) ) {
		next ITEM if $item =~ /^\./;
		
		next ITEM unless $item =~ /$self->{metadatafile}/;
		my $path = "$basedir/$item";
		next ITEM unless -f $path;

		my $md = $self->parse_metadata(path => $path, shortpath => $item);
		
		if( $md ) {
            if( $required && !$md->{metadata}{$required} ) {
                $self->{log}->debug("Skipping $item - no <$required> tag");
                next ITEM;
            }

			my $dataset = $self->{source}->dataset(
				metadata => $md->{metadata},
				location => $md->{location},
				file => $md->{file},
				datastreams => $md->{datastreams}
			);
			if( $dataset ) {
				push @datasets, $dataset;
			} else {
                $self->{log}->error("Dataset creation failed for $path");
            }
		} else {
            $self->{log}->error("Metadata parse failed for $path");
        }
	}
	closedir($dh);
	return @datasets ;
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
