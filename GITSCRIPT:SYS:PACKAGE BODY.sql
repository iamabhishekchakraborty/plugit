CREATE OR REPLACE PACKAGE BODY gitscript
IS
    FUNCTION sh( git_bin VARCHAR2, working_dir all_directories.directory_path%TYPE ) RETURN gitscript.config
    IS  ret gitscript.config;
    BEGIN
        ret.job_action := '/bin/sh';
        ret.script_code :=
'#!/bin/sh
outputFile=$1
debugText="$@"
shift
outputText=$('||git_bin||' "$@" 2>'||chr(38)||'1)
echo "$outputText" > '||working_dir||'"$outputFile" 
echo "$debugText"  > '||working_dir||'"$outputFile"_debug
';
        RETURN ret;
    END sh;
END gitscript;
