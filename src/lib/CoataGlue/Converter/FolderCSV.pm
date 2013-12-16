package CoataGlue::Converter::FolderCSV;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use Text::CSV;
use MIME::Types qw(by_suffix);

# MIME type to use when MIME::Types can't deduce it

my $FALLBACKMIME = 'application/octet-stream';

=head1 NAME

CoataGlue::Converter::FolderCSV

=head1 DESCRIPTION

Generic converter for data like this:

/basedir/datadir/metadata.csv
                 ... and data ...
        /dd2/
        /dd3/
        
        
If the CSV file does not specify a location (in a column headed
'location') then the folder is used.

TODO: scan the directory with the .csv file for other files
and add them to a 'payload' arrayref.  These can then be 
imported into Fedora if required.

=head1 METHODS


=over 4

=item init(basedir => $base, datadir => $datadir, metadatafile => $file)

Initialise with the following params:

=over 4

=item basedir - Base directory to scan
=item datadir - Regexp matching data directories
=item metadatafile - Fileglob pattern matching the metadata csv files

=back


=cut



sub init {
	my ( $self, %params ) = @_;
	
	$self->{csv} = Text::CSV->new() || do {
		$self->{log}->error("Can't use Text:CSV: " .  Text::CSV->error_diag());
		die;
	};
	
	my $missing = 0;
	for my $field ( qw(basedir datadir metadatafile) ) {
		if( !$params{$field} ) {
			$missing = 1;
			$self->{log}->error("$self->{name} missing config $field");
		} else {
			$self->{$field} = $params{$field};
		}
	}
	
	if( $missing ) {
		return undef;
	} else {
		return $self;
	}
}


=item scan()

Scans directory and returns a list of datasets

=cut

sub scan {
	my ( $self ) = @_;
	
	my $basedir = $self->{basedir};
	my $datadir = $self->{datadir};
	
	if( ! -d $basedir ) {
		$self->{log}->error("$basedir is not a directory");
		die;
	}
	
	opendir(my $dh, $basedir) || do {
		$self->error("Can't open $basedir: $!");
		return undef;
	};
	
	my @datasets = ();
	
	ITEM: for my $item ( readdir($dh) ) {
		next ITEM if $item =~ /^\./;
		my $path = "$basedir/$item";
		next ITEM unless -d $path;
		
		my $md = $self->get_metadata(path => $path, shortpath => $item);
		
		
		if( $md ) {
			my $dataset = $self->{source}->dataset(
				metadata => $md->{metadata},
				file => $md->{file},
				location => $md->{location},
				datastreams => $md->{datastreams}
			);	
			if( $dataset ) {
				push @datasets, $dataset;
			}
		} 
	}
	closedir($dh);
	return @datasets ;
}


=item get_metadata(path => $path, shortpath => $shortpath)

Look for the metadata file in a data directory

=cut


sub get_metadata {
	my ( $self, %params ) = @_;
	
	my $path = $params{path};
	my $shortpath = $params{shortpath};
	# scan through the dataset folder for something that
	# matches the file pattern
	
	opendir(my $dh, $path) || do {
		$self->{log}->error("Couldn't open $path, $!");
		return undef;
	};
	
	my %metadata = ();
	my $datastreams = {};
	
	while( my $item = readdir($dh) ) {
		$self->{log}->debug("Scanning $shortpath/$item");
		if( $item =~ /$self->{metadatafile}/ ) {
			$self->{log}->debug("Metadata file $shortpath/$item");
			my $file = "$path/$item";
			if( -f $file ) {
				if( my $md = $self->parse_metadata_file(file => "$path/$item") ) {
#					if( !$md->{location} ) {
#						$md->{location} = $path;
#					}
					$metadata{$file} = $md;
				}
			}
		} elsif( $item !~ /^\./ ) {
			$self->{log}->debug("Adding datastream $shortpath/$item");
            my ( $mimetype, $encoding ) = by_suffix($item);
            $self->{log}->debug("MIME type = $mimetype");
            if( !$mimetype ) {
                $self->{log}->info("No MIME type, defaulting to $FALLBACKMIME");
                $mimetype = $FALLBACKMIME;
            }
            
            $datastreams->{$item} = {
				id => $item,
				original => "$path/$item",
				mimetype => $mimetype
			};
		}
	}
	
	
	if( ! keys %metadata ) {
		$self->{log}->warn("Dir $shortpath has no metadata file: skipping");
		return undef;
	}

	my ( $file ) = sort keys %metadata;
	my $md = $metadata{$file};
	
	if( scalar(keys %metadata) > 1 ) {
		$self->{log}->warn("Warning: $path has more than one metadata file - using $file");
	}
	
	return {
		file => $file,
		location => $path,
		metadata => $md,
		datastreams => $datastreams
	};

}

=item parse_metadata_file(file => $file)

Parses the csv metadata file

=cut


sub parse_metadata_file {
	my ( $self, %params ) = @_;
	
	my $file = $params{file};

	open(my $fh, "<:encoding(utf8)", $file) || do {
		$self->{log}->error("Can't open $file for reading: $!");
		return undef;
	};
	
	my @rows = ();
	while ( my $row = $self->{csv}->getline($fh) ) {
		push @rows, $row;
	}
	
	if( scalar(@rows) < 2 ) {
		$self->{log}->error("Bad CSV in $file: must have two rows (header and values)");
		return undef;
	}
	
	if( scalar(@rows) > 2 ) {
		$self->{log}->warn("Suspect CSV in $file: more than two rows");
	}
	
	my $headers = $rows[0];
	my $values = $rows[1];
	
	my $metadata = {};

	HEADER: for my $name ( @$headers ) {
		if( !@$values ) {
			$self->{log}->warn("Suspect CSV in $file: more headers than values");
			last HEADER;
		}
		$metadata->{$name} = shift @$values;
	}

	if( @$values ) {
		$self->{log}->warn("Suspect CSV in $file: more values than headers");
	}
	
	$metadata->{dateconverted} = $self->timestamp;

    $self->{log}->debug("*** metadata " . Dumper({m => $metadata}));

	return $metadata;	
}


=back

=cut


1;
