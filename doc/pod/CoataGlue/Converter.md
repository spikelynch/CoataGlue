# NAME

CoataGlue::Converter

# DESCRIPTION

Converters scan files or directories (or any other type of digital
record), crosswalk the metadata and return CoataGlue::Datasets (populated
with CoataGlue::Datastreams).

The base class uses Module::Pluggable to scan and register the
CoataGlue::Converter::\* subclasses, which can be instantiated by
calling the converter() method on the base class.

# SYNOPSIS

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

# PLUGINS

The main CoataGlue object creates a single CoataGlue::Converter.
This then uses Module::Pluggable to read in all the subclasses.

# INTERFACE

Each subclass should provide the following methods

- init(%params)

    Initialise the converter. The params will be different for each
    Converter subclass. Params are found in the DataSources.cf file.

    Note that one Converter subclass can be used in many sources.

- scan

    For this source instance, scan the directory (or whatever), convert
    whatever's there into CoataGlue datasets, and return an array of
    them.  The converter does not worry about whether the datasets
    have been seen before - this is handled by the CoataGlue::Source
    instance.

# MIME TYPES

Datastreams need to be assigned a MIME type so that Damyata knows how to
serve them on the web. 

The base class provides a mime\_type method which uses the MIME::Types
module to guess the type.  In cases where this gives the wrong answer,
you can override it by putting a \_MIME section in the Templates/DataSource.cf
file, which maps file extensions to the correct types.

    [_MIME]
    cub:             application/octet-stream
    qub:             application/octet-stream

Or, if this is not enough, you can override the mime\_type method in
your converter class.





# METHODS



- new(%params)

    If called on CoataGlue::Converter, returns a factory class which can be
    used to create new subclass with the converter method.

    If called on a subclass, passes the parameters in and returns a subclass
    instance.

- init()

    Stub method, needs to be provided by the subclass. The init method needs
    to check that all the required settings have been passed in and return
    undef if any are missing.

- scan()

    Stub method, needs to be provided by the subclass.

    Scan should return an array of CoataGlue::Datasets representing new
    collections.

- register\_plugins()

    Calls the Module::Pluggable::plugins method, which scans the file system
    for subclasses. Populates the {plugin} hashref with them.

    Only called on the base class CoataGlue::Converter.

- converter(converter => $plugin\_class, settings => $settings)

    Creates an instance of the Converter of class $plugin\_class with the 
    settings in $settings.  These are taken from the data sources' section of
    the DataSources.cf file and will vary between different types of 
    Converter.

    Returns undef if the plugin class was not found, or if the plugin was
    not initialised (most likely because of missing or out-of-range settings).

- timestamp()

    Returns the current time in a standard format for all converters

- mime\_type(file => $file)

    Deduces the MIME type of $file.  Uses the \_MIME override section in the
    data source's template.cf file: if this doesn't match, uses the MIME::Types
    module.
