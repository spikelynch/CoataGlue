package UTSRDC::DataSource::MIF;

use parent 'UTSRDC::DataSource';

use Config::Std;

sub init {
	my ( $self, %params ) = @_;
	
	$self->readconfig;
	

	return $self;	
}


sub scan {
	
	
	
	
	
}

1;