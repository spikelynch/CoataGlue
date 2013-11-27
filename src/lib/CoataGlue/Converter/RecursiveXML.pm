package CoataGlue::Converter::RecursiveXML;

use strict;

use parent 'CoataGlue::Converter::XML';

use Data::Dumper;
use XML::Twig;
use MIME::Types qw(by_suffix);

=head1 NAME

CoataGlue::Converter::RecursiveXML

=head1 DESCRIPTION

Extension of CoataGlue::Converter::XML which does a recursive descent
into a directory structure and gets all files which match the metadata
file pattern.

The metadata parsing code is unchanged - all this module does is provide
a recursive_scan method, and slightly tweak scan() so that it can 
provide a different base_dir for each metadata file.

=head1 CONFIGURATION

metadatafile - pattern to match files
metadatatag -  children of this tag read as metadata. Default is root
require -      if this tag is empty, ignore this record

=head1 NOTES

the 'shortfile' for these is problematic as it is not necessarily unique.

I'm bodging it for now (Nov 2013) but it needs a bit of a rethink.

=head1 METHODS

=over 4

=item scan()

Scans a directory tree for matching metadata files, returns a list
of datasets.

=cut



sub scan {
	my ( $self, %params ) = @_;
	
	my $basedir = $self->{basedir};
	
	if( ! -d $basedir ) {
		$self->{log}->error("$basedir is not a directory");
		die;
	}

    $self->{xmlfiles} = [];

    $self->recursive_scan(dir => $basedir);

    my @datasets = ();

    for my $path ( @{$self->{xmlfiles}} ) {
        $self->{log}->debug("Path $path");

        my @spath = split('/', $path);
        my $short = pop @spath;
        my $base = join('/', @spath) . '/';

        # SUPER::parse_metadata lets us override 'basedir' 
        # (which in Converter::XML is the same for all datasets)
        # with this collection's $USER/$JOBID directory

		my $md = $self->parse_metadata(
            element => '',
            path => $path,
            shortpath => $short,
            basedir => $base
            );
		
		if( $md ) {
			my $dataset = $self->{source}->dataset(
				metadata => $md->{metadata},
				location => $md->{location},
				file => $md->{file},
				datastreams => $md->{datastreams}
			);
			if( $dataset ) {
                $self->{log}->debug("Got dataset $dataset->{id}");
				push @datasets, $dataset;
			} else {
                $self->{log}->error("Dataset creation failed for $path");
            }
		} else {
            $self->{log}->error("Metadata parse failed for $path");
        }
    }
    $self->{log}->debug("Scanned " . scalar(@datasets) . " datasets");
	return @datasets;
}


=item recursive_scan(dir => $dir)

Scans $dir, pushing all files matching the {metadatafile} pattern onto an
array {xmlfiles}, and recursing into any child directories.

=cut


sub recursive_scan {
    my ( $self, %params ) = @_;

    my $dir = $params{dir};

    $self->{log}->trace("Recursively entering $dir");
    
	opendir(my $dh, $dir) || do {
		$self->error("Can't open $dir: $!");
		return undef;
	};
	
	ITEM: for my $item ( readdir($dh) ) {
		next ITEM if $item =~ /^\./;
        my $path = "$dir/$item";
		
		if( $item =~ /$self->{metadatafile}/ ) {
            next ITEM unless -f $path;
            $self->{log}->trace("Collected file $path");
            push @{$self->{xmlfiles}}, $path;
        } else {
            if( -d $path ) {
                $self->recursive_scan(dir => $path);
            }
		}
    }
	closedir($dh);
}


=back

=cut


1;
