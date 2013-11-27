# NAME

CoataGlue::Converter::RecursiveXML

# DESCRIPTION

Extension of CoataGlue::Converter::XML which does a recursive descent
into a directory structure and gets all files which match the metadata
file pattern.

The metadata parsing code is unchanged - all this module does is provide
a recursive\_scan method, and slightly tweak scan() so that it can 
provide a different base\_dir for each metadata file.

# CONFIGURATION

metadatafile - pattern to match files
metadatatag -  children of this tag read as metadata. Default is root
require -      if this tag is empty, ignore this record

# NOTES

the 'shortfile' for these is problematic as it is not necessarily unique.

I'm bodging it for now (Nov 2013) but it needs a bit of a rethink.

# METHODS

- scan()

    Scans a directory tree for matching metadata files, returns a list
    of datasets.

- recursive\_scan(dir => $dir)

    Scans $dir, pushing all files matching the {metadatafile} pattern onto an
    array {xmlfiles}, and recursing into any child directories.
