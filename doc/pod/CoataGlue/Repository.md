# NAME

CoataGlue::Repository

# DESCRIPTION

Wrapper around the interface to Fedora, which is kind of messy
because it needs two different Catmandu classes. In the future
this could be the basis of a plugin/adapter setup which allows
other kinds of repositories.

May one day be used by Damyata to look things up.

# SYNOPSIS

    my $repo = CoataGlue::Repository->new(
	    baseurl => $url,
	    usename => $username,
	    password => $password
    );
    
    my $id = $repo->add_object(dataset => $dataset);

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		file => $datafile
	);

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		url => $dataurl
	);

	$repo->set_datastream(
		id => $id,
		dsid => $dsid,
		xml => $dataxml
	);

	

# METHODS

- new(baseurl => $url, username => $username, password => $password)

Create a new object; returns undef if any of the parameters are missing.

- add\_object(dataset => $dataset)

Creates a new Fedora object for the dataset, populates the dublin core
metadata and returns the repository id for the new object if succesful.

- set\_datastream(%params)

Add or rewrite a datastream on a Fedora object. Parameters are

- pid - the dataset's Fedora ID
- dsid - the datastream ID, which has to conform to Fedora's rules

The CoataGlue::IDset class is a utility for cleaning up sets of ids so that
they can be used as Fedora ids.



- store

Return a Catmandu::Store object for this repository.

- repository

Return a Catmandu::FedoraCommons object for the repository
