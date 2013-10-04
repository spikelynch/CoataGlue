#/bin/bash

export COATAGLUE_HOME=/home/mikelynch/CoataGlue
export COATAGLUE_PERLLIB=/home/mikelynch/CoataGlue/src/lib
export COATAGLUE_LOG4J=$COATAGLUE_HOME/log4j.properties
export COATAGLUE_CONFIG=$COATAGLUE_HOME/Config/CoataGlue.cf
export COATAGLUE_SOURCES=$COATAGLUE_HOME/Config/DataSources.cf
export COATAGLUE_TEMPLATES=$COATAGLUE_HOME/Config/Templates

/home/mikelynch/CoataGlue/src/harvest.pl

