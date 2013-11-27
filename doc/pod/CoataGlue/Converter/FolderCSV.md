# NAME

CoataGlue::Converter::FolderCSV

# DESCRIPTION

Generic converter for data like this:

/basedir/datadir/metadata.csv
                 ... and data ...
        /dd2/
        /dd3/
        

        

If the CSV file does not specify a location (in a column headed
'location') then the folder is used.

TODO: scan the directory with the .csv file for other files
and add them to a 'payload' arrayref.  These can then be 
imported into Fedora if required.

# METHODS



- init(basedir => $base, datadir => $datadir, metadatafile => $file)

    Initialise with the following params:

    - basedir - Base directory to scan
    =item datadir - Regexp matching data directories
    =item metadatafile - Fileglob pattern matching the metadata csv files



- scan()

    Scans directory and returns a list of datasets

- get\_metadata(path => $path, shortpath => $shortpath)

    Look for the metadata file in a data directory

- parse\_metadata\_file(file => $file)

    Parses the csv metadata file
