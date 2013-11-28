Damyata

Dancer module to control access to datasets in Fedora Commons 
based on their settings in the Research Data Catalogue (RDC)

All datasets in the RDC are assigned a digital object in Fedora,
whether they're being published on the web or not.  For a given
dataset D, there exists:

- A Fedora digital object with an ID like 'RDC.n'
- A dataset URL like 'http://research.uts.edu.au/damyata/RDC.n'
- A ReDBox dataset with the URL as an identifier

Damyata accepts dataset URLs and does the following:

- Look up the request URL in the RDC (via the Solr API)
- Get the dataset's access setting from the RDC:
    - If the dataset is public, return the landing page
    - If the dataset is UTS-only, return the landing page if the request is from UTS
    - If neither of the above, return a 'not found' page
- If the dataset was not found, return a 'not found' page.

Damyata generates the landing page based on the metadata values
returned from the RDC, and by looking up the Fedora record to 
find the datastreams.

- get /

    A placeholder.  

- get /about

    About, contact, credits

- get /:id

    The landing page for a dataset

- load\_config()

    Loads and validates the app's config variables.  Calls error
    and dies if any are missing or invalid.

- find\_dataset(%params)

    Looks up the dataset by its URI in Solr.  If it's found, also
    looks it up in Fedora to get the list of datastreams.

    Parameters:

    - uri
    =item fedora\_id 
    =item solr\_field
    =item redbox\_map

    The return value is a hash as follows:

    - title
    =item description
    =item access
    =item created
    =item creator\_title
    =item creator\_familyname
    =item creator\_givenname
    =item datastreams

    FIXME: this needs to get more info from ReDBox

    Mapping from the ReDBox/Solr index to these fieldnames is controlled
    by redbox\_map in the config file.

    All of the values are scalars except for 'datastreams', which is an
    arrayref of hashes as follows:

    - dsid
    =item label
    =item mimeType
    =item url



- find\_datastreams(fedora\_id => $fedora\_id)

    Looks the dataset up in Fedora and returns a list of datastreams.
    The list is an arrayref of hashrefs: keys are dsid, mimeType and
    label.

    This filters out any datastream with the id DC (that's the Dublin
    Core metadata, which is already on the landing page).

    This method broke when I started dropping the colons out of Fedora IDs
    back up the chain -- because they're illegal in Windows filesystems,
    and we might want to build zips with folder names containing them.

    Now if it doesn't find a colon in the ID, it pulls the number off the
    end and reinstates it.

- request\_is\_local

    Return true if this request is 'local'

- test\_dataset

    Returns a mock dataset for testing the page templates and css

    - title
    =item description
    =item access
    =item created
    =item creator\_title
    =item creator\_familyname
    =item creator\_givenname
    =item datastreams



    - dsid
    =item label
    =item mimeType
    =item url




