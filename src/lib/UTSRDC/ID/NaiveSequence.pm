package UTSRDC::ID::NaiveSequence;

use strict;
use Log::Log4perl;

=head1 NAME

UTSRDC::ID::NaiveSequence

=head1 SYNOPSIS

Dumb-as-a-box-of-hammers module for generating unique IDs
by incrementing the highest sequence number in the source
history.

If you want this to work well when there is more than one
process for the same source, you'll have to write a smarter
version which uses some sort of locking to stop two processes
getting the same sequence number.

Rough idea:

    my $id = $IDs->new_id
    
    ... add the new ID to the source history while other
        processes wanting IDs wait till you're done...
         
    $IDs->release 
    
    ... now other processes will get IDs


=cut



sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	
	$self->{source} = $params{source} || die;
	
	return $self;
}


sub new_id {
	my ( $self ) = @_;
	
	my $history = $self->{source}{history} || die(
		"Can't mint new sequence IDs before source has loaded history"
	);
	
	my $id = undef;
	
	if( ! keys %$history ) {
		$id = 1;
	} else {
		my @ids = sort {
			$history->{$b}{id} <=> $history->{$a}{id}
		} keys %$history;		
		$id = $ids[0] + 1;
	}
	return $id;
}


sub release {
	
	# This is called after the Source has created the dataset
	# with the new ID and added it to the history.  In a smarter
	# module, this would release a lockfile.
	
}
