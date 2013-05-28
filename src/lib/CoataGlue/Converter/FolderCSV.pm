package CoataGlue::Converter::FolderCSV;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use Text::CSV;

=head1 NAME

CoataGlue::Converter::FolderCSV

=head1 SYNOPSIS

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




sub scan {
	my ( $self, %params ) = @_;
	
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
		
		my $md = $self->get_metadata(path => $path);
		
		if( $md ) {
			my $dataset = $self->{source}->dataset(
				metadata => $md->{metadata},
				file => $md->{file},
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


sub get_metadata {
	my ( $self, %params ) = @_;
	
	my $path = $params{path};
	
	# scan through the dataset folder for something that
	# matches the file pattern
	
	opendir(my $dh, $path) || do {
		$self->{log}->error("Couldn't open $path, $!");
		return undef;
	};
	
	my %metadata = ();
	my @datastreams = ();
	
	while( my $item = readdir($dh) ) {
		$self->{log}->debug("Scanning $path/$item");
		if( $item =~ /$self->{metadatafile}/ ) {
			$self->{log}->debug("Metadata file $path/$item");
			my $file = "$path/$item";
			if( -f $file ) {
				if( my $md = $self->parse_metadata_file(file => "$path/$item") ) {
					if( !$md->{location} ) {
						$md->{location} = $path;
					}
					$metadata{$file} = $md;
				}
			}
		} elsif( $item !~ /^\./ ) {
			$self->{log}->debug("Adding datastream $path/$item");
			push @datastreams, "$path/$item";
		}
	}
	
	
	if( ! keys %metadata ) {
		$self->{log}->error("Error: no file matches $path/$self->{metadatafile}");
		return undef;
	}

	my ( $file ) = sort keys %metadata;
	my $md = $metadata{$file};
	
	if( scalar(keys %metadata) > 1 ) {
		$self->{log}->warn("Warning: $path has more than one metadata file - using $file");
	}
	
	return {
		file => $file,
		metadata => $md,
		datastreams => \@datastreams
	};

}

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

	return $metadata;	
}



1;