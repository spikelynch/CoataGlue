package CoataGlue::Converter;

use strict;

=head1 NAME

CoataGlue::Converter

=head1 DESCRIPTION

Converters scan files or directories (or any other type of digital
record), crosswalk the metadata and return CoataGlue::Datasets (populated
with CoataGlue::Datastreams).

The base class uses Module::Pluggable to scan and register the
CoataGlue::Converter::* subclasses, which can be instantiated by
calling the converter() method on the base class.

=head1 SYNOPSIS

    # Get a singleton 
    my $cc = CoataGlue::Converter->new();

    my $converter = $cc->converter(
		converter => "CoataGlue::Converter::XML,
		settings => \%settings
	);

    for my $dataset ( $converter->scan ) {
    	...
    }
    

The converters are not called directly, but by calling ->scan on 
a CoataGlue::Source instance.

=head1 PLUGINS

The main CoataGlue object creates a single CoataGlue::Converter.
This then uses Module::Pluggable to read in all the subclasses.

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

=head1 MIME TYPES

Datastreams need to be assigned a MIME type so that Damyata knows how to
serve them on the web. 

The base class provides a mime_type method which uses the MIME::Types
module to guess the type.  In cases where this gives the wrong answer,
you can override it by putting a _MIME section in the Templates/DataSource.cf
file, which maps file extensions to the correct types.

    [_MIME]
    cub:             application/octet-stream
    qub:             application/octet-stream

Or, if this is not enough, you can override the mime_type method in
your converter class.

=head1 FIXME

Document the data structures to be fed in by child classes.

    $datastreams->{$file} = {
        id => $file,
        original => $file,
        mimetype => $mimetype
    }

=cut

use Module::Pluggable search_path => [ 'CoataGlue::Converter' ], require => 1, on_require_error => \&plugin_crash;

use Config::Std;
use Log::Log4perl;
use Data::Dumper;
use Catmandu::Store::FedoraCommons;

use Carp qw(cluck);
use Data::Dumper;
use POSIX qw(strftime);

use MIME::Types qw(by_suffix);

my $crashed_plugins = {};

=head1 METHODS

=over 4


=item new(%params)

If called on CoataGlue::Converter, returns a factory class which can be
used to create new subclass with the converter method.

If called on a subclass, passes the parameters in and returns a subclass
instance.

=cut


sub new {
    my ( $class, %params ) = @_;
    
    my $self = {};
    bless $self, $class;
    
    $self->{log} = Log::Log4perl->get_logger($class);
    
    if( $class eq 'CoataGlue::Converter' ) {
        $self->register_plugins(%params);
        return $self;
    } else {
        return $self->init(%params)
    }
}


=item init()

Stub method, needs to be provided by the subclass. The init method needs
to check that all the required settings have been passed in and return
undef if any are missing.

=cut

sub init {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need an init method (" . ref($self) . ")");
	die;
}

=item plugin_crash($plugin, $error)

Passed to Module::Pluggable's on_require_error parameter - is called if any
of the plugins fails to compile.

=cut
    
sub plugin_crash {
    my ( $plugin, $error ) = @_;

    my $log = Log::Log4perl->get_logger('CoataGlue::Converter');
    
    $log->error("Plugin crash: $plugin");
    $log->error("Error: $error");
    $crashed_plugins->{$plugin} = 1;
    return 0;
}

=item scan()

Stub method, needs to be provided by the subclass.

Scan should return an array of CoataGlue::Datasets representing new
collections.

=cut


sub scan {
	my ( $self ) = @_;
	
	$self->{log}->error("All CoataGlue::Converter subclasses need a scan method (" . ref($self) . ")");
	die;
}



=item register_plugins()

Calls the Module::Pluggable::plugins method, which scans the file system
for subclasses. Populates the {plugin} hashref with them.

Only called on the base class CoataGlue::Converter.

=cut




sub register_plugins {
    my ( $self, %params ) = @_;
    
    $self->{log}->debug("Registering plugins...");

    my @plugins = $self->plugins; 

#    $self->{log}->debug("Got plugins " . join(' ', @plugins));
    
    for my $plugin ( @plugins ) {
        if( $crashed_plugins->{$plugin} ) {
            $self->{log}->error("Skipping plugin $plugin");
        } else {
            $self->{plugins}{$plugin} = 1;
        }
    }
}


    

=item converter(converter => $plugin_class, settings => $settings)

Creates an instance of the Converter of class $plugin_class with the 
settings in $settings.  These are taken from the data sources' section of
the DataSources.cf file and will vary between different types of 
Converter.

Returns undef if the plugin class was not found, or if the plugin was
not initialised (most likely because of missing or out-of-range settings).

=cut


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

=item timestamp()

Returns the current time in a standard format for all converters

=cut

sub timestamp {
	my ( $self ) = @_;
	
	my $format = $self->{source}->conf('General', 'timeformat');
	
	return strftime($format, localtime);
}

=item mime_type(file => $file)

Deduces the MIME type of $file.  Uses the _MIME override section in the
data source's template.cf file: if this doesn't match, uses the MIME::Types
module.

=cut

sub mime_type {
    my ( $self, %params ) = @_;

    my $file = $params{file};

    if( my $overrides = $self->{source}->MIME_overrides ) {
        if( $file =~ /\.([^.]*)$/ ) {
            my $ext = $1;
            if( $overrides->{$ext} ) {
                $self->{log}->debug("Overriding MIME type $ext = $overrides->{$ext}");
                return $overrides->{$ext};
            }
        }
    }
   return by_suffix($file);
}


    
=back

=cut


1;
