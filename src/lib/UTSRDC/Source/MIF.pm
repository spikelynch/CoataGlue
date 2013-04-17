package UTSRDC::DataSource::MIF;

use strict;

use parent 'UTSRDC::DataSource';

use Data::Dumper;
use Text::CSV;

sub init {
	my ( $self, %params ) = @_;
	
	$self->{csv} = Text::CSV->new() || do {
		$self->{log}->error("Can't use Text:CSV: " .  Text::CSV->error_diag());
		die;
	};
	
	return $self;	
}


sub scan {
	my ( $self ) = @_;
	
	my @directories = $self->scan_directories(
		basedir => $self->{conf}{basedir},
		dir     => qr/$self->{conf}{datadir}/,
		
	);
	
	my @datasets = ();
	for my $dir ( @directories ) {
		push @datasets, $self->read_metadata(dir => $dir);
	}
	
	return @datasets
}



sub scan_directories {
	my ( $self, %params ) = @_;
	
	my $basedir = $params{basedir} || die("scan_directories needs a dir");
	
	if( ! -d $basedir ) {
		$self->error("$basedir is not a directory");
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
		
		my $dataset = $self->get_metadata(path => $path);
		if( $dataset ) {
			push @datasets, $dataset;
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
	
	my $file_re = $self->{conf}{metadatafile};
	while( my $item = readdir($dh) ) {
		if( $item =~ /$self->{metadatafile}/ && -f "$path/$item" ) {
			my $dataset = $self->parse_metadata_file(file => "$path/$item");
			return $dataset;
		}
	}
	$self->{log}->error("No file matching $self->{metadatafile}")
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
	
	my $ds = UTSRDC::Dataset->new(
		id => $file,
		metadata => $metadata,
		location => $file
	);
	return $ds
}



1;