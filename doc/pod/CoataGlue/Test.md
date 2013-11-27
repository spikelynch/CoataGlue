# NAME

CoataGlue::Test

# SYNOPSIS

    use CoataGlue::Test qw(setup_tests is_fedora_up);

    my $LOG4J = "$Bin/log4j.properties";
    my $LOGGER = "CoataGlue.tests.006_fedora";
    Log::Log4perl->init($LOG4J);
    my $log = Log::Log4perl->get_logger($LOGGER);

    my $fixtures = setup_tests(log => $log);

    my $CoataGlue = CoataGlue->new(%{$fixtures->{LOCATIONS}});

    ok($CoataGlue, "Initialised CoataGlue object");

    my $repo = $CoataGlue->repository;

    ok($repo, "Connected to Fedora Commons");

    if( !is_fedora_up(log => $log, repository => $repo) ) {
        die("Fedora is down.\n");
    }

# DESCRIPTION

Utility routines to build up test fixtures and confirm that Fedora is 
open for business.

# METHODS

- setup\_tests(log => $log)

    Copies the test fixtures into the test directory.  Returns a data
    structure containing the parsed fixture information so that it can be
    used for comparisons in tests.

- load\_file(file => $file)

    Load a text file and return the contents as a single scalar

- is\_fedora\_up(log => $log, repository => $repo)

    Tries to connect to the repository: returns 0 if it can't.
