# NAME

CoataGlue::IDset

# SYNOPSIS

    my $idset = CoataGlue::IDset->new(raw => $raw);

    my $cooked = $idset->make_ids;

    for my $newid ( keys %$cooked ) {
       my $value = $raw->{$cooked->{$newid}};
       
       # do something with $newid and $value...
    }



A class to convert a set of raw ids into a set of ids which can be
used as datastream IDs in Fedora, and which are still all unique.

Fedora requires that ids be XML NCnames no more than 64 chars.  This
tries to come up with a set of IDs which conform to that rule, which
are still all unique, and which preserve anything that looks like a 
file extension (since this is used to deduce MIME types).

It also truncates from the front of the id, because when IDs are very
long path names, the front is the least interesting, and the back has
information we want to preserve, like the filename, or the user
directory it was found in, etc.

The raw ids are passed in as a hashref with the ids as keys.  The values
of this hashref are ignored.

The make\_ids method returns a hashref of newid => oldid (or undef in
the unlikely event that you tried this with 10^64 ids and there was a
collision).





# METHODS

- new(raw => $raw)

    Create a new IDset, with $raw as the hash with ids as keys.

- make\_ids()

    Return a hashref whose keys are clean and unique, and whose values are
    the old ids they map to.

    If unique creation failed, return undef.

- add\_id(id => $id)

    Adds a raw id to the hash, returns undef if this failed.

- has\_dsid(id => $id, ext => $ext)

    Reassemble the id with dsid and checks if it's already in 
    the datastreams hash.

- dsid(id => $id, ext => $ext)

    Utility to reassemble an id and the file extension. Returns
    "$id.$ext" if $ext is defined, otherwise just returns $id
