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