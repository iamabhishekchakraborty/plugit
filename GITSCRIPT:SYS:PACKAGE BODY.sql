CREATE OR REPLACE PACKAGE BODY gitScript
IS
    FUNCTION sh( gitBin VARCHAR2, workingDir all_directories.directory_path%TYPE ) RETURN gitScript.config
    IS  ret gitScript.config;
    BEGIN
        ret.job_action := '/bin/sh';
        ret.scriptCode :=
'#!/bin/sh
outputFile=$1
debugText="$@"
shift
outputText=$('||gitBin||' "$@" 2>'||chr(38)||'1)
echo "$outputText" > '||workingDir||'"$outputFile" 
echo "$debugText"  > '||workingDir||'"$outputFile"_debug
';
        RETURN ret;
    END sh;
END gitScript;