# NAME

CoataGlue::Datastream

# SYNOPSIS

    my $ds = $dataset->datastreams;

    for my $dsid ( sort keys %$ds ) {
        my $datastream = $ds->{$dsid};
        my $url = $datastream->url;
        my $siz = $datastream->size;
        my $format = $datastream->format
        $datastream->write(label => "Datastream $dsid $format");
    }



# DESCRIPTION

An object to represent a datastream - an atomic object (file or URL).
Datastream is Fedora Core terminology.  A Dataset can have many
datastreams

- original  - The original file (or URL maybe later)
- id        - the Fedora datastream id - has to be an XML NCNAME
                  no greated than 64 characters
                  
- label     - a user-friendly label
- url       - the URL of the datastream as hosted on the web
- dataset   - link back to the parent dataset

When a dataset is created from an ingested object, as many datastreams
as needed are created from whatever the Converter class passes in, and
their IDs are corrected so that they can be used as Fedora dsids.

# METHODS

- new(%params)

    Create a new datastream object.

    - dataset  - the dataset that owns it
    - original - the original file - has to be unique for this dataset
    - id       - a unique token (within the dataset)
    - oid      - the original id as passed to the Dataset object
    - mimetype - MIME type

- conf($section, $field)

    Get a config value from the Coataglue object

- url()

    Returns this datastream's public URL.  Datastreams have to be in a
    'section' (public/local/etc) which they always inherit from their
    parent dataset

- write(%params)

    Write the datastream to Fedora, updating any params that 
    are passed in. Parameters (all optional)

    - xml|file|url
    =item label
    =item mimetype

- size()

    Return the size of this datastream in raw bytes.  Use
    Number::Bytes::Human::format\_bytes downstream if you need to - it's
    not used here so that the sizes can be added for the Dataset manifest

- format

    Returns the file extension (not the MIME-type, which is less useful for
    human-readability purposes - a lot of formats don't have one.)
