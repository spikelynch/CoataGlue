CoataGlue - Overview
====================

CoataGlue is a software framework for crosswalking metadata and
datasets from data capture apps into the UTS Research Data Catalogue.
It handles the following:

* Polling a set of different data capture sources for new data collections

* Scanning data collections (in different formats), extracting
  metadata, and crosswalking metadata into a single common metadata
  format.

* Looking up extended metadata fields - such as researcher names and
  titles - from a Mint naming authority

* Writing metadata records into a file system where they can be
  harvested by ReDBox

* Copying data payloads into a Fedora Commons repository

* Serving data collections (and data payloads) on the web via a
  landing page app which controls access to datasets based on their
  RDC record (ie private, UTS-only, public)

Terminology
-----------

* Dataset - a collection of research data with a singe title,
  description, principal author, other metadata, and possibly a URL
  and/or DOI.  Datasets can contain more than one file (and more than
  one type of file).  They may also be called 'records' or
  'collections' (in ReDBoxese) or 'digital objects' (in Fedorian).
  The line between a dataset and a collection is not prescribed and
  comes down to the researcher's own practice and the standards in her
  discipline.

* Datastream - Fedoran terminology for a single file.  A Fedora object
  (and a dataset) can have any number of datastreams.

* Source - a data capture source.  All datasets from a single source
  will be in te same format (for some value of 'same' - it depends on
  the converter)

* Converter - a CoataGlue plugin which reads datasets and metadata and
  crosswalks the metadata into the standard metadata format.  Each
  Source has one and only one Converter, but one Converter can be used
  for lots of Sources.


Components
----------

[CoataGlue Core]

[Damyata]
 