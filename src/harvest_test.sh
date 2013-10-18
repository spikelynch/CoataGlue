#/bin/bash

# Run the harvest script in 'test' mode (which forgets it has scanned the
# fixtures datasets and will keep incrementing the filename IDs in the
# ReDBox alerts XML)
#
# To actually reset the fixtures, call harvest_test.sh -f




export COATAGLUE_HOME=/home/mikelynch/DataCapture
export COATAGLUE_PERLLIB=/home/mikelynch/CoataGlue/src/lib
export COATAGLUE_LOG4J=$COATAGLUE_HOME/log4j.properties
export COATAGLUE_CONFIG=$COATAGLUE_HOME/Config/CoataGlue.cf
export COATAGLUE_SOURCES=$COATAGLUE_HOME/Config/DataSources.cf
export COATAGLUE_TEMPLATES=$COATAGLUE_HOME/Config/Templates


while getopts ":f" opt; do
    case $opt in
        f)
            /home/mikelynch/CoataGlue/src/t/fixtures.pl
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done



/home/mikelynch/CoataGlue/src/coataglue.pl -t
