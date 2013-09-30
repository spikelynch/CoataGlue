package CoataGlue::Converter::XML;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;
use MIME::Types qw(by_suffix);

=head1 NAME

CoataGlue::Converter::XML

=head1 SYNOPSIS

Generic converter for XML metadata

=cut



sub init {
	my ( $self, %params ) = @_;
	
	$self->{twig} = XML::Twig->new();	
	
	my $missing = 0;
	for my $field ( qw(basedir metadatafile datastreams) ) {
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
	
	if( ! -d $basedir ) {
		$self->{log}->error("$basedir is not a directory");
		die;
	}
	
	opendir(my $dh, $basedir) || do {
		$self->error("Can't open $basedir: $!");
		return undef;
	};
	
	$self->{log}->debug("Scanning $basedir");
	
	my @datasets = ();
	
	ITEM: for my $item ( readdir($dh) ) {
		next ITEM if $item =~ /^\./;
		
		$self->{log}->debug("Scanning $item");
		next ITEM unless $item =~ /$self->{metadatafile}/;
		my $path = "$basedir/$item";
		next ITEM unless -f $path;
		
		my $md = $self->parse_metadata(path => $path, shortpath => $item);
		
		if( $md ) {
			my $dataset = $self->{source}->dataset(
				metadata => $md->{metadata},
				location => $md->{location},
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


sub parse_metadata {
	my ( $self, %params ) = @_;
	
	my $path = $params{path};
	my $shortpath = $params{shortpath};
	
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
	
	for my $elt ( $tw->root->children ) {
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
		if( !ref($ds) ) {
			$ds = [ $ds ];
		}
		for my $file ( @$ds ) {
			if( $file =~ /^file:\/\/(.*)$/ ) {
				$file = $self->{basedir} . $1;
				if( -f $file ) {
                    my ( $mimetype, $encoding ) = by_suffix($file);
					$datastreams->{$file} = {
						id => $file,
						original => $file,
						mimetype => $mimetype
					};
				} else {
					$self->{log}->error("Datastream $file not found");
				}
			} else {
				$self->{log}->warn("XML converter can only handle local files");
			}
		}
	}

	$md->{dateconverted} = $self->timestamp;
	
    $self->{log}->debug("Metadata: " . Dumper({md => $md}));

	return {
		file => $path,
		location => $path,
		metadata => $md,
		datastreams => $datastreams
	};
}

1;
