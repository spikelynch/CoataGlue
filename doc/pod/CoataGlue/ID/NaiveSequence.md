# NAME

CoataGlue::ID::NaiveSequence

# SYNOPSIS

    my $seq = CoataGlue::ID::NaiveSequence->new(source => $source);

    # $new_id will be > the highest existing id in $source

    my $new_id = $seq->create_id;



# DESCRIPTION

Dumb-as-a-box-of-hammers module for generating unique IDs
by incrementing the highest sequence number in the source
history.

If you want this to work well when there is more than one
process for the same source, you'll have to write a smarter
version which uses some sort of locking to stop two processes
getting the same sequence number.

Rough idea:

    my $id = $IDs->create_id([test => 1])
    
    ... add the new ID to the source history while other
        processes wanting IDs wait till you're done...
         
    $IDs->release 
    
    ... now other processes will get IDs



# METHODS

- new(source => $source)

    Create a new sequencer linked to $source.



- create\_id()

    Create a new ID by finding the highest id in the source history and
    adding one.

- release()

    Stub method: this class doesn't do locking but if one ever gets written,
    releasing the lock will happen here.
