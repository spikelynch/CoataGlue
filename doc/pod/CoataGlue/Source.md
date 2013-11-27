# NAME

CoataGlue::Source

# SYNOPSIS

    my @sources = $CoataGlue->sources;
    
    for my $source ( @sources ) {
    	my @datasets = $source->scan;
    	
       	for my $ds ( @datasets ) {
       		if( $ds->write_xml ) { 
    		   		$ds->set_status_ingested()
       		} else {
       			$ds->set_status_error();
       		}
       	}
       }
       

# DESCRIPTION

Basic object describing a data source

- name      - unique id
- converter - A CoataGlue::Converter object (passed in by CoataGlue)
- settings  - the config settings (some of which depend on the Converter)
- store     - the directory where the source histories are kept 

    # STATUS

    Each source has a history file in the store/ directory which keeps
    track of the status of each dataset which has been scanned. The
    process works like this:

    \- The $source->scan() function uses the Converter object to 
      scan whatever it scans (a directory within a directory, in
      FolderCSV). The Converter gets datasets with a unique-to-
      this-source string, typically a filepath.  
      

    \- The Source then gets an exclusive lock on its history file,
      reads it, and looks up all the scanned datasets by their
      filepath.  If they have already been ingested or have raised
      errors, it ignores them.  The remaining datasets are new,
      and get new IDs from the ID generator class (these are 
      unique IDs which can be used as filenames).
      

    \- The Source passes the list of datasets back to the calling
      code, which will attempt to Do Things (write out the XML
      and add the datasets to Fedora etc).  Based on how successful
      this is, the calling code sets the status for each dataset,
      and the Source writes the status into the history
      

    \- At the end of this process, the calling code 
      should call $source->close - which writes the history file
      and releases the lock
       



    # METHODS

- new(%params)

    Create a new Source. Parameters:

    - coataglue - the CoataGlue object
    - name - unique name of this Source
    - converter - the CoataGlue::Converter class
    - ids - the ID uniquifier
    - settings - the settings hash from the config file
    - store - the directory where store files are written

- open()

    This reads the Source's history file with an exclusive lock, 
    so if any other processes try to scan this source, they'll have
    to wait.

- close()

    Saves the source's history hash to the store file and releases the
    lock.

- get\_status(dataset => $dataset)

    Looks up the status of a dataset in this source's history.  Returns the
    'new' status if it's not there.

- set\_status(dataset => $dataset, status => $status)

    Set the dataset's status in the history file.

- skip()

    Returns true if the 'skip' flag in the datasource config is set.
    Used to skip broken converters when testing.

- scan(\[test => 1\])

    Calls scan on this source's converter and returns all datasets 
    which haven't been ingested on a previous pass.

    If a true value is passed in for 'test', this will output metadata
    files to the test metadata directory but not touch the history

- test\_scan

    Test version of scan.  I broke this out into its own subroutine because
    doing both test and live in the same loop was creating code that was too
    complicated around the id incrementation.

- dataset(%params)

    Creates a new dataset based on the parameters:

    - metadata - metadata hash
    - file - the actual metadata file
    - location - the file's location (usually a dir)
    - datastreams - a hashref of datastreams

- load\_templates

    Loads this data source's template config.

- crosswalk(dataset => $ds, view => $view)

    Applies a crosswalk from this view's template file.  If
    no view is supplied, it applies the standard metadata crosswalk
    to the raw metadata from the converter.  If a view is supplied,
    and it isn't 'metadata', it runs one of the other views defined
    in the file on the standard metadata (and creates this first
    if it hasn't yet been built)

- get\_person(id => $id)

    Takes a staff ID and calls CoataGlue::Person::lookup to find them in 
    Mint.

- staff\_id\_to\_handle

    This method has been superseded by get\_person (above) but I'm leaving it
    in because some of the tests use it.  FIXME

- render\_view(dataset => $ds, view => $view)

    Generate an XML view of a dataset.  Expansion works like this:
    the top level is a crosswalk into XML elements.  Each of these 
    elements can either be a straight copy from one of the metadata
    fields, or an expansion of a template.  The templates have access
    to all of the metadata of the dataset, so (for example) technical
    metadata fields can be combined into a single 'description' element.

    All XML views get an 'header' element at the top which contains the
    dataset's origin file, id, location, repositoryURL, date converted
    and 'publish' flag

    Returns the resulting XML.



- write\_header\_XML(writer => $writer)

    Add the standard header tag

- write\_creator\_XML(writer => $writer)

    Add the standard creator tag

- expand\_template(template => $template, metadata => $metadata)

    Populate one of the templated elements with a template file

- repository

    Initialises a connection to the Fedora repository if it's not
    already been made, and returns it as a Catmandu::Store object

- repository\_crosswalk(%metadata)

    Crosswalks a standard metadata hash into a DC hashref to
    be added to the Fedora repository

- conf

    Get config values from the Coataglue object

- make\_handler(expr => $expr, field => $field)

    Generates a handler function for a field, based on $expr.

- date\_handler(field => $field, expr => $expr)

        date($RE, $f1, $f2, $f3)

    Where $RE is a regular expression matching groups for date
    components, and the $f1... are YEAR MON DAY HOUR MIN SEC.

    For example,

        date((\d+)\/(\d+)\/(\d+), DAY, MON, YEAR)

    will match and convert dates like 31/12/1969

    It's assumed that MON is either 1..12 or a string which matches
    (jan|feb|mar...) and the year is four digits: other years will throw
    an error.

- parse\_month(month => $month)

    Takes months either as 1-12 or names (Jan, January) and returns a value
    0-11 to pass to strftime

- map\_handler(map => $configmap)

    Maps raw values onto another set, as defined by the \[map\] section of
    the source's config file

- timestamp\_handler

    This just appends a timestamp to the end of the field value.  A utility
    for testing so that you can tell which version of a test dataset is 
    which.

- MIME\_overrides

    If there are any \_MIME overrides, return them as a hashref
