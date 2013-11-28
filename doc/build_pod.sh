#!/bin/bash

pod2markdown ../src/lib/CoataGlue.pm                > ./pod/CoataGlue.md
pod2markdown ../src/lib/CoataGlue/Converter.pm      > ./pod/CoataGlue/Converter.md
pod2markdown ../src/lib/CoataGlue/Converter/FolderCSV.pm > ./pod/CoataGlue/Converter/FolderCSV.md
pod2markdown ../src/lib/CoataGlue/Converter/XML.pm       > ./pod/CoataGlue/Converter/XML.md
pod2markdown ../src/lib/CoataGlue/Converter/RecursiveXML.pm      > ./pod/CoataGlue/Converter/RecursiveXML.md
pod2markdown ../src/lib/CoataGlue/Dataset.pm      > ./pod/CoataGlue/Dataset.md
pod2markdown ../src/lib/CoataGlue/Datastream.pm      > ./pod/CoataGlue/Datastream.md
pod2markdown ../src/lib/CoataGlue/ID/NaiveSequence.pm      > ./pod/CoataGlue/ID/NaiveSequence.md
pod2markdown ../src/lib/CoataGlue/IDset.pm      > ./pod/CoataGlue/IDset.md
pod2markdown ../src/lib/CoataGlue/Person.pm      > ./pod/CoataGlue/Person.md
pod2markdown ../src/lib/CoataGlue/Repository.pm      > ./pod/CoataGlue/Repository.md
pod2markdown ../src/lib/CoataGlue/Source.pm      > ./pod/CoataGlue/Source.md
pod2markdown ../src/lib/CoataGlue/Test.pm      > ./pod/CoataGlue/Test.md

pod2markdown ../Damyata/lib/Damyata.pm         > ./pod/Damyata.md
