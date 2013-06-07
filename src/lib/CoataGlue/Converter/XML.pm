package CoataGlue::Converter::XML;

use strict;

use parent 'CoataGlue::Converter';

use Data::Dumper;
use XML::Twig;

=head1 NAME

CoataGlue::Converter::XML

=head1 SYNOPSIS

Generic converter for XML metadata

=cut



sub init {
	my ( $self, %params ) = @_;
	
	$self->{twig} = XML::Twig->new();	
	
	my $missing = 0;
	for my $field ( qw(basedir metadatafile) ) {
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
	
	my @datasets = ();
	
	ITEM: for my $item ( readdir($dh) ) {
		next ITEM if $item =~ /^\./;
		next ITEM unless $item =~ /$self->{metadatafile}/;
		my $path = "$basedir/$item";
		next ITEM unless -f $path;
		
		my $md = $self->parse_metadata(path => $path, shortpath => $item);
		
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
	
	return $md;
}

1;