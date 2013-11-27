# NAME

CoataGlue::Person

# DESCRIPTION

Class representing researchers.  Has code to encrypt staff IDs to form
safe handles, and a method to look up researchers by handle in Mint's solr
index.

# METHODS

- new(id => $ID, source => $SOURCE, \[ %details \])

    New is used to create stub Person objects for encrypting IDs.  It is
    also used as a kind of mock method to run tests without needing an
    operational Mint server.

    It needs a staff ID and a CoataGlue::Source, at least.



- lookup(solr => $solr, id => $id)

    Works like 'new' but looks up the details by encrypted staff id in Mint.

- creator()

    Return a $hashref of fields for the <creator> tag in the metadata interchange
    format, as follows:

    - staffid
    - mintid
    - name
    - givenname
    - familyname
    - honorific
    - name
    - encrypt\_id()

        Encrypt a staff ID to put in a handle
