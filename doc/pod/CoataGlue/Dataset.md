# NAME

CoataGlue::Dataset

# SYNOPSIS

	my $dataset = CoataGlue::Dataset->new(
		source => $self,
		file => $file,
		location => $location,
		raw_metadata => $metadata,
		datastreams => $datastreams
	)|| do {
		$self->{log}->error("Error creating dataset");
		return undef;	
	};

    my $ds = $dataset->datastreams;

    my $id = $dataset->global_id;

    my $handle = $dataset->handle;

    $dataset->handle_request || die("Write handle failed");

    my $manifest = $dataset->manifest;

    my $file = $dataset->short_file;

    my $status = $dataset->get_status;

    $dataset->set_status_ingested;

    $dataset->set_status_error;

    $dataset->clean_metadata_keys;

    my $md = $dataset->metadata;

    my $header = $dataset->header;

    my $url = $dataset->url;

    my $repo_id = $dataset->safe_repository_id 
    my $xml = $dataset->xml(view => $view);

    $dataset->write_redbox || die("couldn't write!");

       if( $dataset->is_publish_target(to => $target) {
    
        $dataset->publish(to => $target);

        my $access = $dataset->access;
     }

     my $xmlfile = $dataset->xml_filename

     if( $dataset->add_to_repository() ) {
         my $streams = $dataset->create_datastreams(raw => $raw_ds);
     }

        my $datastreams = $dataset->datastreams;
    
     my $conf = $dataset->conf($section, $field);

# DESCRIPTION

CoataGlue's main job is creating metadata records in the RDC for
datasets from a variety of sources (data capture, mostly).  The
CoataGlue::Dataset class represents a single dataset and its
metadata, and has methods for the following useful operations:

- Writing out XML for ReDBox ingest
- Writing out other XML representations, controlled by a fairly
flexible templating system
- Adding an object to Fedora representing the dataset
- Copying the payload to a Fedora-hosted file system when the
data object is published

# VARIABLES

- file           -> the metadata file
- location       -> dataset location (a directory in a filesystem)
- raw\_metadata   -> a hashref of the raw metadata from the Converter
- metadata       -> the crosswalked metadata
- id             -> unique in this Source, no weird chars
- globalid       -> Source name + id
- repositoryURL  -> The URL in Fedora
- source         -> the datasource name
- datecreated    -> experiment date from the source
- dateconverted  -> date it was converted
- datastreams    -> an arrayref of payloads (files or URLs)
- access         -> who can access it / where it's published



The standard metadata fields are as follows. 

- title
- description
- activity
- service
- creationdate
- collectiondate
- group
- creator
- supervisor
- access
- spatial
- temporal
- location
- keywords
- manifest

# METHODS

- new(%params)

    Create a new dataset object. All parameters apart from datastreams
    are compulsory.

    - source - the CoataGlue::Source
    - file - the metadata file - has to be unique for this dataset
    - location - the directory of the dataset (usually contains file)
    - raw\_metadata - a hashref of the raw metadata as read by the converter
          Non-alphanumeric characters in keys are converted to underscores.
          
    - datastreams - an arrayref of payloads hashrefs which should have the following:
        - file or xml or url
        - id - a unique string (first character must be \[A-Za-z\]) 
        - mimetype - optional

- global\_id()

    Returns the dataset's global unique ID:

    $SOURCE->{name}:$self->{id}

- handle() 

    Makes a SHA hash from the dataset's source name + metadata location
    and prepends it to our handle URL.

- handle\_request()

    Write out a batch file for creating a handle which points to this 
    dataset's URL

- manifest()

    Manifest - returns a summary of the file contents which can be used in 
    the extent-or-quantity field of ReDBox

- short\_file()

    Returns the filename relative to the capture directory

- get\_status()

    Returns this dataset's status as a hash:

        {
    	    status => 'new', 'ingested', 'error',
    	    err_msg => error message if status = 'error'	
        }

- set\_status\_ingested

    Sets this dataset's status to ingested

- set\_status\_error

    Sets this dataset's status to error

- clean\_metadata\_keys()

    CLean up the metadata keys so that they can be used as variables in
    Template::Toolkit.  Any non-alphanumeric characters at the end are
    truncated; all other non-alphanumeric characters are replaced with
    underscores.

    Throws an error if two keys convert down to the same string.

- metadata()

    Crosswalk the raw metadata into the basic metadata fields for FC or
    ReDBox and return a hash.

- header()

    This returns the source, id, repository\_id etc.  Metadata about
    metadata, which is why it's called 'header'

- url

    Return the URL of this dataset in the repository.

- safe\_repository\_id()

    This removes the colon from the dataset's repository ID.  Some day we'll
    implement a 'get this dataset as a zip' feature and the filenames will
    break on Windows if they have colons.  Thanks, Paul.

- xml(view => $view)

    Apply the specified xml view to this dataset and return the
    results.  The default view is 'metadata'

- write\_redbox(\[test => 1\])

    Writes the 'redbox' XML to the redbox directory, using the global\_id
    as the filename.

    If the param 'test' is true, write it to the test directory.

- publish(\[to => $audience\])

    Version of the publish method where hosted datastreams are stored
    in a filesystem and pushed into Fedora as URLs.  For this to work,
    the datastreams need to be available on the web as served by 
    Damyata before they are pushed into Fedora.

    Copies this dataset to the requested 'audience'.  An audience 
    is a directory in the base web publishing director with one
    set of authentication rules (ie UTS only, AAF, public etc):

        ...dancer app/public/data/$audience/$pid/$dsid.$ext
        

    A dataset can only be in one of these folders, so if the 
    publication status changes, it's deleted from the current
    one after it's been successfully added to the new one.

    If no audience is passed in, the datastream's metadata.access value
    is used.

    This method also updates the datastreams in the Fedora object
    so that they point to the new URLs.

- access()

    Returns the access category of the dateset: basically, who can see
    it.  Corresponds to a directory in the web hosting setup.

- is\_publish\_target(to => $to) 

    Returns true if $to is a valid publication target (as defined by
    Publish.targets in the global config).



- xml\_filename()

    Returns the full path of the xml file built from the source's
    ReDBox directory and the dataset's global ID.

- add\_to\_repository()

    Create a digital object representing this dataset in the repository
    (Fedora Commons for now although we should eventually make it
    anything accessible via Catmandu::Store)

- create\_datastreams(raw => $hashref)

    Takes a hashref of raw datastreams and uses Dataset::IDset to 
    convert the raw keys to values which Fedora Commons will accept.

    Then adds Datastream objects with the new ids.

    See Dataset::IDset for the details of how IDs are converted.

- datastreams

    Returns a hash of datastreams by id - the ids are not the original
    ids but the cleaned-up, Fedora-safe ones.

- conf

    Get config values from the Coataglue object
