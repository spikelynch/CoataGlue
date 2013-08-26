#!/bin/bash

# NOTE: this script is obsolete, since I fixed the tests so that they
# use FindBin to figure out where they are being run.

# runtests.sh [ $testscript ]

# This sets up environment variables and then runs either $testscript
# or, if $testscript is not specified, runs 'prove' (which will run all
# of the test scripts in t/)

# NOTE: ./t/Test will get overwritten with the fixtures from t/Fixtures
# before any of the scripts runs. So any changes to config files need
# to be made to ./t/Fixtures/.. not ./t/Test/..

export COATAGLUE_CONFIG=./t/Test/Config/CoataGlue.cf
export COATAGLUE_FIXTURES=./t/Fixtures
export COATAGLUE_LOG4J=./t/log4j.properties
export COATAGLUE_PERLLIB=./lib
export COATAGLUE_SOURCES=./t/Test/Config/DataSources.cf
export COATAGLUE_TEMPLATES=./Test/Config/Templates
export COATAGLUE_TESTDIR=./t/Test

if [ $1 ]; then
    $1
else
    prove
fi
