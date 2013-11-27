# NAME

CoataGlue

# DESCRIPTION

Object representing a CoataGlue installation.

# SYNOPSIS

    my $coataglue = CoataGlue->new(
        home      => $CG_HOME_DIR,
	    global    => $CG_GLOBAL_CONF,
	    sources   => $CG_SOURCES_CONF,
	    templates => $CG_TEMPLATES_DIR
    );

    my @sources = $coataglue->sources;

    my $repo = $coataglue->repository;

    my $solr = $coataglue->mint;

# CONFIGURATION

See the Wiki: https://github.com/spikelynch/CoataGlue/wiki/Configuration









# METHODS

- new(%params)

    Create an new CoataGlue object.  Parameters:

    - home - CoataGlue installation directory
    - global - The global config file (see CONFIGURATION)
    - sources - The data source config file (see DATA SOURCES)
    - templates - The metadata templates directory (see TEMPLATES)

    If either of the config files can't be parsed, returns undef.

    If an individual data source's config is unparsable, this will be logged
    but the CoataGlue object will be returned.

- sources()

    Return an array of all data sources

- conf($section, $field)

    Return a configuration values

- expand\_conf()

    Goes through all the config values and expands $COATAGLUE to the value
    of $self->{home}

- template

    Obsolete method: template expansion now in CoataGlue::Source

- repository()

    Returns a CoataGlue::Repository object connected to the repository, or
    undef if connection fails.

- repository\_crosswalk(metadata => $metadata)

    Crosswalks a dataset's metadata into the fields expected by the repository,
    based on the RepositoryCrosswalk config section.

- mint()

    Returns an Apache::Solr object for doing lookups in Mint for 
    researcher details


