package Damyata;

=head NAME

Damyata

=head DESCRIPTION

Dancer module to control access to datasets in Fedora Commons 
based on their settings in the Research Data Catalogue (RDC)

=head SYNOPSIS

All datasets in the RDC are assigned a digital object in Fedora,
whether they're being published on the web or not.  For a given
dataset D, there exists:

=over 4

=item A Fedora digital object with an ID like 'RDC.n'

=item A dataset URL like 'http://research.uts.edu.au/damyata/RDC.n'

=item A ReDBox dataset with the URL as an identifier

=back

Damyata accepts dataset URLs and does the following:

=over 4

=item Look up the request URL in the RDC (via the Solr API)

=item Get the dataset's access setting from the RDC:

=over 4

=item If the dataset is public, return the landing page

=item If the dataset is UTS-only, return the landing page if the request is from UTS

=item If neither of the above, return a 'not found' page

=back

=item If the dataset was not found, return a 'not found' page.

=back

Damyata generates the landing page based on the metadata values
returned from the RDC, and by looking up the Fedora record to 
find the datastreams.

=cut

use Dancer ':syntax';

use Apache::Solr;
use Data::Dumper;

use MIME::Types qw(by_suffix);
use Number::Bytes::Human qw(format_bytes);

use Catmandu::FedoraCommons;

our $VERSION = '0.1';

our %REQUIRED_CONF = (
	solr => [ qw(server core search) ],
	fedora => [ qw(url user password) ],
	redbox_map => [ qw(
		title description access created
		creator_title creator_familyname creator_givenname
	) ],
	urls => [ qw(datasets datastreams) ],
    webroot => 1
);

our @OPTIONAL_CONF = qw(fake_baseurl test_page);

my $conf = load_config();


my $solr = Apache::Solr->new(
    server => $conf->{solr}{server},
    core => $conf->{solr}{core}
) || do {
	error("Couldn't connect to ReDBox/Solr");
	die;
};


my $fedora = Catmandu::FedoraCommons->new(
	$conf->{fedora}{url},
	$conf->{fedora}{user},
	$conf->{fedora}{password}
) || do {
	error("Couldn't connect to Fedora Commons");
	die;
};


=head ROUTES

=over 4

=item get /

A placeholder.  

=cut

get '/' => sub {
    template 'index', { test_page => $conf->{test_page} };
};


=item get /about

About, contact, credits

=cut

get '/about' => sub { title => 'About', template 'about' };




=item get /:id

The landing page for a dataset

=cut


get '/:id' => sub {
	
	my $id = param('id');

	my $uri = request->uri;
	my $base = undef;
	
	if( $conf->{fake_baseurl} ) {
		$base = $conf->{fake_baseurl};		
	} else {
		$base = request->uri_base; 
	}

    if( $conf->{urls}{datasets} ) {
        $uri = $conf->{urls}{datasets} . $uri;
    } else {
        $uri = $base . $uri;
    }

	my $dataset = undef;

    if( $id eq $conf->{test_page} ) {
        $dataset = test_dataset();
    } else {
        $dataset = find_dataset(
		solr_field => $conf->{solr}{search},
		redbox_map => $conf->{redbox_map},
		fedora_id => $id,
		uri => $uri
            );
    }
	
	if( !$dataset ) {
		template 'not_found' => { uri => $uri };
	} else {
		if( $dataset->{access} eq 'uts' && !request_is_local() ) {
			template 'forbidden' => { uri => $uri };
		} else {
			template 'dataset' => $dataset
		}
	}
};




=back

=head METHODS

=over 4

=item load_config()

Loads and validates the app's config variables.  Calls error
and dies if any are missing or invalid.

=cut


sub load_config {

	my $conf = {};
	
	# build the config hash and die if any mandatory fields
	# are missing
	
	my $missing = 0;
	for my $section ( keys %REQUIRED_CONF ) {
		my $req = $REQUIRED_CONF{$section};
		$conf->{$section} = config->{$section};
		if( ! $conf->{$section} ) {
			error("Missing config section $section");
			$missing = 1;
		} else {
            if( ref($req) ) {
                for my $value ( @$req ) {
                    if( ! $conf->{$section}{$value} ) {
                        error("Missing config value $section.$value");
                        $missing = 1;
                    }
                }
            }
		}
	}
	die if $missing;
	
	$conf->{solr}{search} =~ s/:/\\:/g;
	
	# optional fields
	
    for my $field ( @OPTIONAL_CONF ) {
        $conf->{$field} = config->{$field};
    }

	return $conf;
}

=item find_dataset(%params)

Looks up the dataset by its URI in Solr.  If it's found, also
looks it up in Fedora to get the list of datastreams.

Parameters:

=over 4

=item uri
=item fedora_id 
=item solr_field
=item redbox_map

=back

The return value is a hash as follows:

=over 4

=item title
=item description
=item access
=item created
=item creator_title
=item creator_familyname
=item creator_givenname
=item datastreams

=back

FIXME: this needs to get more info from ReDBox

Mapping from the ReDBox/Solr index to these fieldnames is controlled
by redbox_map in the config file.

All of the values are scalars except for 'datastreams', which is an
arrayref of hashes as follows:

=over 4

=item dsid
=item label
=item mimeType
=item url

=back


=cut

sub find_dataset {
	my %params = @_;
	
	my $uri = $params{uri} || return undef;
	my $fedora_id = $params{fedora_id} || return undef;
	my $urifield = $params{solr_field};
	my $redbox_map = $params{redbox_map};
	
	my $esc_uri = $uri;

	$esc_uri =~ s/:/\\:/g;
	
	my $solr_query = join(':', $urifield, $esc_uri);

	my $results = $solr->select(q => $solr_query);
	
	my $n = $results->nrSelected;
	
	if( !$n ) {
		debug("URI '$uri' not found in Solr.");
		return undef;
	}
	
	if( $n > 1 ) {
		warn("More than one Solr index with URI '$uri'");
	} else {
		debug("Found a result for '$uri'");
	}
	
	my $doc = $results->selected(0);
	
	my $dataset = {};
	
	for my $field ( keys %$redbox_map ) {
		$dataset->{$field} = $doc->content($redbox_map->{$field}) || '';
	}
	
	$dataset->{datastreams} = find_datastreams(fedora_id => $fedora_id);
	
	# build a url for each datastream.. also hackily look up the
    # file size in the web hosting directory
	
    my $access = $dataset->{access};

    if( !$access ) {
        $access = 'public';
    }

    for my $ds ( @{$dataset->{datastreams}} ) {
        $ds->{url} = join(
            '/', $conf->{urls}{datastreams}, 
            $access, $fedora_id, $ds->{dsid}
            );
        my $file = join('/',
                        $conf->{webroot}, $access, $fedora_id, $ds->{dsid}
            );
        my $size = '';
        if( $size = -s $file ) {
            $size = format_bytes($size);
        }
        $ds->{size} = $size;
    }

    return $dataset;
}


=item find_datastreams(fedora_id => $fedora_id)

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

=cut


sub find_datastreams {
	my %params = @_;
	
	
	my $fedora_id = $params{fedora_id};
	my $datastreams = {};

    if( $fedora_id !~ /:/ ) {
        if( $fedora_id =~ /^(\D+)(\d+)$/ ) {
            $fedora_id = join(':', $1, $2);
        } else {
            warn("No colon in fedora_id $fedora_id but couldn't split and repair");
        }
    }
            
	my $result = $fedora->listDatastreams(pid => $fedora_id);

	if( $result->is_ok ) {
		my $dss = $result->parse_content;
        my $no_dc = [ grep { $_->{dsid} ne 'DC' } @{$dss->{datastream}} ];
		return $no_dc;
	} else {
		debug("Error looking up datastreams in FC: " . $result->error);
		return []
	}
}


=item request_is_local

Return true if this request is 'local'

=cut



sub request_is_local {
	return true;
}


=item test_dataset

Returns a mock dataset for testing the page templates and css

=over 4

=item title
=item description
=item access
=item created
=item creator_title
=item creator_familyname
=item creator_givenname
=item datastreams

=back


=over 4

=item dsid
=item label
=item mimeType
=item url

=back



=cut

sub test_dataset {

    return {
        title => 'Test Dataset',
        description => '<p>This is a placeholder</p><p>For testing</p>',
        access => 'public',
        created => '12 September 2013',
        creator_title => 'Dr',
        creator_familyname => 'Smith',
        creator_givenname => 'Jane',
        creator_email => 'Jane.Smith@institution',
        creator_url => 'http://www.uts.edu.au/~jane.smith',
        datastreams => [
            {
                dsid => 'DS1',
                label => 'Datastream1.jpg',
                mimeType => 'image/jpg',
                url => 'http://localhost/Datastream1.jpg',
                size => '10M'
            },
            {
                dsid => 'DS2',
                label => 'Datastream2.jpg',
                mimeType => 'image/jpg',
                url => 'http://localhost/Datastream1.jpg',
                size => '12K'
            }
            ]
    };
}

true;
