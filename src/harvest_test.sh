#/bin/bash

# Run the harvest script in 'test' mode (which forgets it has scanned the
# fixtures datasets and will keep incrementing the filename IDs in the
# ReDBox alerts XML)
#
# To actually reset the fixtures, call harvest_test.sh -f




export COATAGLUE_HOME=/home/mike/workspace/RDC\ Data\ Capture
export COATAGLUE_PERLLIB=$COATAGLUE_HOME/src/lib
export COATAGLUE_LOG4J=$COATAGLUE_HOME/src/t/log4j.properties
export COATAGLUE_CONFIG=$COATAGLUE_HOME/src/t/Test/Config/CoataGlue.cf
export COATAGLUE_SOURCES=$COATAGLUE_HOME/src/t/Test/Config/DataSources.cf
export COATAGLUE_TEMPLATES=$COATAGLUE_HOME/src/t/Test/Config/Templates


while getopts ":f" opt; do
    case $opt in
        f)
            ./t/fixtures.pl
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done


./harvest.pl -t

