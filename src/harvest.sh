#/bin/bash

export COATAGLUE_HOME=/home/mike/workspace/RDC\ Data\ Capture
export COATAGLUE_PERLLIB=$COATAGLUE_HOME/src/lib
export COATAGLUE_LOG4J=$COATAGLUE_HOME/src/t/log4j.properties
export COATAGLUE_CONFIG=$COATAGLUE_HOME/src/t/Test/Config/CoataGlue.cf
export COATAGLUE_SOURCES=$COATAGLUE_HOME/src/t/Test/Config/DataSources.cf
export COATAGLUE_TEMPLATES=$COATAGLUE_HOME/src/t/Test/Config/Templates

./harvest.pl

