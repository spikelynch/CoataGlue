#!/bin/bash

export COATAGLUE_CONFIG=./t/Test/Config/CoataGlue.cf
export COATAGLUE_FIXTURES=./t/Fixtures
export COATAGLUE_LOG4J=./t/log4j.properties
export COATAGLUE_PERLLIB=./lib
export COATAGLUE_SOURCES=./t/Test/Config/DataSources.cf
export COATAGLUE_TEMPLATES=./Test/Config/Templates
export COATAGLUE_TESTDIR=./t/Test

$1
