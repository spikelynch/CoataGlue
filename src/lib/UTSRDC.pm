package UTSRDC;

use Config::Std;
use Log::Log4perl;

my $LOGGER = 'UTSRDC';

Log::Log4perl::init($ENV{UTSRDC_LOG4J});

my $log = Log::Log4perl->get_logger($LOGGER);

sub new {
	my ( $class, %params ) = @_;
		
	
	
	
}