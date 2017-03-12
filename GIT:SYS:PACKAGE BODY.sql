CREATE OR REPLACE PACKAGE BODY git
IS
    gitBinPath CONSTANT VARCHAR2(400) := '/usr/bin/git';
    srcDirName CONSTANT all_directories.directory_name%TYPE := 'VERSION_CONTROL';
    srcDirPath all_directories.directory_path%TYPE;
    gitWrapper gitScript.config; 

    FUNCTION init RETURN CLOB
    IS BEGIN
        SELECT directory_path
        INTO srcDirPath
        FROM all_directories
        WHERE directory_name = srcDirName;

        gitWrapper := gitScript.sh( gitBinPath, srcDirPath );
        dbms_xslprocessor.clob2file( gitWrapper.scriptCode, srcDirName, gitWrapper.scriptFile );
        dbms_xslprocessor.clob2file( gitWrapper.scriptFile, srcDirName, '.gitignore' );

        RETURN git.run( git.args('init'));
    END init;

    FUNCTION srcFilename( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN VARCHAR2
    IS BEGIN
        RETURN name||':'||owner||':'||type||'.sql';
    END srcFilename;

    PROCEDURE save( name VARCHAR2, owner VARCHAR2, type VARCHAR2, source CLOB )
    IS BEGIN
        dbms_xslprocessor.clob2file( source, srcDirName, srcFilename(name,owner,type));
    END save;

    FUNCTION run( customArgs args ) RETURN CLOB
    IS
        outputFile CONSTANT VARCHAR2(250) := 'output'||'_'||TO_CHAR(SYSDATE,'YYYYMMDD_HH:MI:SS')||'_'||SYS_CONTEXT('USERENV', 'SESSIONID');

        forcedArgs CONSTANT git.args :=
            args(
              srcDirPath||gitWrapper.scriptFile
            , outputFile
            , '--git-dir'   , srcDirPath||'.git'
            , '--work-tree' , srcDirPath
            );

        stdout CLOB;
    BEGIN
        DBMS_SCHEDULER.CREATE_JOB
        ( job_name            => 'git_run'
        , job_type            => 'EXECUTABLE'
        , job_action          => gitWrapper.job_action
        , auto_drop           => TRUE
        , number_of_arguments => forcedArgs.COUNT+customArgs.COUNT
        );

        FOR i IN 1..forcedArgs.COUNT+customArgs.COUNT
        LOOP
            IF i <= forcedArgs.COUNT
            THEN DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE( 'git_run', i, forcedArgs(i));
            ELSE DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE( 'git_run', i, customArgs(i-forcedArgs.COUNT));
            END IF;
        END LOOP;

        BEGIN dbms_scheduler.run_job ('git_run'); EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN dbms_scheduler.drop_job('git_run'); EXCEPTION WHEN OTHERS THEN NULL; END;

        stdout :=   '******** debug *****************'
        ||CHR(10)|| DBMS_XSLPROCESSOR.READ2CLOB(flocation => srcDirName,fname => outputFile||'_debug')
        ||CHR(10)|| '********************************'
        ||CHR(10)|| DBMS_XSLPROCESSOR.READ2CLOB(flocation => srcDirName,fname => outputFile);

        UTL_FILE.FREMOVE(srcDirName,outputFile||'_debug');
        UTL_FILE.FREMOVE(srcDirName,outputFile);

        RETURN stdout;
    END run;

    FUNCTION reset RETURN CLOB
    IS BEGIN
        RETURN git.run( git.args('reset'));
    END reset;

    FUNCTION status RETURN CLOB
    IS BEGIN
        RETURN git.run( git.args('status'));
    END status;

    FUNCTION add( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB
    IS BEGIN
        RETURN git.run( git.args( 'add', srcFilename( name,owner,type )));
    END add;

    FUNCTION commit( message VARCHAR2 ) RETURN CLOB
    IS BEGIN
        RETURN git.run( git.args
          ( '-c', 'user.name=' ||USER
          , '-c', 'user.email='||UTL_INADDR.get_host_name
          , 'commit', '-m', message
          )
        );
    END commit;

    FUNCTION rm(name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB
    IS  stdout CLOB;
    BEGIN
        stdout := git.run( git.args( 'rm', srcFilename( name,owner,type )));

        IF ora_dict_obj_type = 'PACKAGE'
        THEN stdout :=
              stdout || chr(10)
              || git.run( git.args( 'rm', srcFilename( name,owner,type => 'PACKAGE BODY' )));
        END IF;

        RETURN stdout;
    END rm;

    PROCEDURE mute(ignored VARCHAR2) IS BEGIN NULL; END;
BEGIN
    mute(git.init());
END git;