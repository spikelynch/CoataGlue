#/bin/bash

# a version of the harvest runner which builds the fixtures (as with the
# t/ regression tests)



export COATAGLUE_HOME=/home/mike/workspace/RDC\ Data\ Capture
export COATAGLUE_PERLLIB=/home/mike/workspace/RDC\ Data\ Capture/src/lib
export COATAGLUE_LOG4J=/home/mike/workspace/RDC\ Data\ Capture/src/t/log4j.properties
export COATAGLUE_CONFIG=/home/mike/workspace/RDC\ Data\ Capture/src/t/Test/Config/CoataGlue.cf
export COATAGLUE_SOURCES=/home/mike/workspace/RDC\ Data\ Capture/src/t/Test/Config/DataSources.cf
export COATAGLUE_TEMPLATES=/home/mike/workspace/RDC\ Data\ Capture/src/t/Test/Config/Templates

./t/fixtures.pl

./harvest.pl

