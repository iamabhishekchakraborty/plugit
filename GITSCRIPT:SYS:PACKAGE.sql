CREATE OR REPLACE PACKAGE gitScript
IS
    TYPE config IS RECORD (
      scriptFile VARCHAR2(40) DEFAULT 'gitWrapper'
    , job_action VARCHAR2(400)
    , scriptCode CLOB
    );
    FUNCTION sh( gitBin VARCHAR2, workingDir all_directories.directory_path%TYPE ) RETURN gitScript.config;
END gitScript;
