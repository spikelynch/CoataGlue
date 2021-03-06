package CoataGlue::ID::NaiveSequence;

use strict;
use Log::Log4perl;
use Data::Dumper;

=head1 NAME

CoataGlue::ID::NaiveSequence

=head1 SYNOPSIS

    my $seq = CoataGlue::ID::NaiveSequence->new(source => $source);

    # $new_id will be > the highest existing id in $source

    my $new_id = $seq->create_id;


=head1 DESCRIPTION

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


=head1 METHODS

=over 4

=item new(source => $source)

Create a new sequencer linked to $source.


=cut



sub new {
	my ( $class, %params ) = @_;
	
	my $self = {};
	
	bless $self, $class;
	
	$self->{log} = Log::Log4perl->get_logger($class);
	
	
	$self->{source} = $params{source} || die;
	
	return $self;
}


=item create_id()

Create a new ID by finding the highest id in the source history and
adding one.

=cut

sub create_id {
	my ( $self ) = @_;
	
	my $history = $self->{source}{history} || die(
		"Can't mint new sequence IDs before source has loaded history"
	);
	
	my $id = undef;
	
	if( ! keys %$history ) {
		$self->{log}->debug("Empty history");
		$id = 1;
	} else {
		# Find the highest ID in the history and add one to it.
		$self->{log}->debug("Finding ids");
		my @ids = sort { $history->{$b}{id} <=> $history->{$a}{id} } keys %$history;
		$id = $history->{$ids[0]}{id};
		$self->{log}->debug("Highest id = $id");
		$id++;
	}
	$self->{log}->debug("New id = $id");
	return $id;
}


=item release()

Stub method: this class doesn't do locking but if one ever gets written,
releasing the lock will happen here.

=cut

sub release {
	
	# This is called after the Source has created the dataset
	# with the new ID and added it to the history.  In a smarter
	# module, this would release a lockfile.
	
}

=back

=cut

1;
