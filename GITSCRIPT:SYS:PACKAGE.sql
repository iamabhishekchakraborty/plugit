CREATE OR REPLACE PACKAGE gitscript
IS
    TYPE config IS RECORD (
      script_file VARCHAR2(40) DEFAULT 'git_wrapper'
    , job_action VARCHAR2(400)
    , script_code CLOB
    );
    FUNCTION sh( git_bin VARCHAR2, working_dir all_directories.directory_path%TYPE ) RETURN gitscript.config;
END gitscript;
