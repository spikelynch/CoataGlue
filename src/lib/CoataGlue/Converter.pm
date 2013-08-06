package CoataGlue::Converter;

use strict;

=head1 NAME

CoataGlue::Converter

=head1 DESCRIPTION

Base class for Converters, which scan files or directories (or
any other type of digital record) and return CoataGlue::Datasets.


=head1 SYNOPSIS

    for my $dataset ( $converter->scan ) {
    	...
    }
    
The converters are not called directly, but by calling ->scan on 
a CoataGlue::Source instance.

=head1 PLUGINS

The main CoataGlue object creates a single CoataGlue::Converter.
This then uses Module::Pluggable to read in all thhe subclasses.

=head1 INTERFACE

Each subclass should provide the following methods

=over 4

=item init(%params)

Initialise the converter. The params will be different for each
Converter subclass. Params are found in the DataSources.cf file.

Note that one Converter subclass can be used in many sources.

=item scan

For this source instance, scan the directory (or whatever), convert
whatever's there into CoataGlue datasets, and return an array of
them.  The converter does not worry about whether the datasets
have been seen before - this is handled by the CoataGlue::Source
instance.



=back

=head MIME TYPES

Datastreams need to be assigned a MIME type so that Damyata knows how to
serve them on the web.  In both Converter::FolderCSV and Converter::XML,
the by_suffix function provided by MIME::Types is used to guess the 
MIME type from the file suffix.

It's easy to imagine a situation where the MIME type doesn't correspond
to the file suffix.  If that happens, the Converter module can explicitly
set the MIME type or read it from the data source, but that will need
some coding work.
    

=cut

use Module::Pluggable search_path => [ 'CoataGlue::Converter' ], require => 1;
use Log::Log4perl;use Config::Std;
use Log::Log4perl;
use Data::Dumper;
use Catmandu::Store::FedoraCommons;

use Carp qw(cluck);
use Data::Dumper;
use POSIX qw(strftime);

my $TIMEFORMAT = "%FT%T%z";

sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{log} = Log::Log4perl->get_logger($class);
	
	if( $class eq 'CoataGlue::Converter' ) {
		$self->register_plugins(%params);
		return $self;
	} else {
		$self->init(%params);
		return $self;
	}
}



sub init {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need an init method (" . ref($self) . ")");
	die;
}

sub scan {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need a scan method (" . ref($self) . ")");
	die;
}




sub register_plugins {
	my ( $self, %params ) = @_;
	
	$self->{log}->debug("Registering plugins...");
	
	for my $plugin ( $self->plugins ) {
		$self->{plugins}{$plugin} = 1;
	}
}


# $converter->converter(converter => $plugin_class, settings => $settings)


sub converter {
	my ( $self, %params  ) = @_;
	
	my $plugin = $params{converter};
	my $settings = $params{settings};
	
	if( $self->{plugins}{$plugin} ) {
		return $plugin->new(%{$settings});
	} else {
		$self->{log}->error("Unknown converter '$plugin'");
		return undef;
	}
}

# Returns the current time in a standard format for all converters

sub timestamp {
	my ( $self ) = @_;
	
	my $format = $self->{source}->conf('General', 'timeformat');
	
	return strftime($format, localtime);
}



1;
