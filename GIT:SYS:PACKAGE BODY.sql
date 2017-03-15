create or replace PACKAGE BODY git
IS
    git_bin_path CONSTANT VARCHAR2(400) := 'git';
    src_dir_name CONSTANT all_directories.directory_name%TYPE := 'VERSION_CONTROL';
    src_dir_path all_directories.directory_path%TYPE;
    git_wrapper gitscript.config; 

    FUNCTION init RETURN CLOB
    IS BEGIN
        SELECT directory_path
        INTO src_dir_path
        FROM all_directories
        WHERE directory_name = src_dir_name;

        git_wrapper := gitscript.sh( git_bin_path, src_dir_path );
        dbms_xslprocessor.clob2file( git_wrapper.script_code, src_dir_name, git_wrapper.script_file );
        dbms_xslprocessor.clob2file( git_wrapper.script_file, src_dir_name, '.gitignore' );

        RETURN git.run( git.args('init'));
    END init;

    FUNCTION src_filename( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN VARCHAR2
    IS BEGIN
        RETURN name||':'||owner||':'||type||'.sql';
    END src_filename;

    PROCEDURE save( name VARCHAR2, owner VARCHAR2, type VARCHAR2, source CLOB )
    IS BEGIN
        dbms_xslprocessor.clob2file( source||CHR(10), src_dir_name, src_filename(name,owner,type));
    END save;

    PROCEDURE load( filename VARCHAR2 )
    IS sourcecode CLOB;
    BEGIN
        sourcecode := DBMS_XSLPROCESSOR.READ2CLOB(flocation => src_dir_name,fname => filename);
        EXECUTE IMMEDIATE( sourcecode );
    END load;

    FUNCTION list RETURN git.files
    IS  ret git.files := git.files();
        next_newline_char NUMBER;
        all_tracked_files CLOB := git.run(git.args('ls-tree','--full-tree','-r', '--name-only', 'HEAD'));
    BEGIN
        LOOP
            next_newline_char := INSTR(all_tracked_files, CHR(10));
            EXIT WHEN next_newline_char = 0;

            ret.EXTEND;
            ret(ret.COUNT)    := SUBSTR( all_tracked_files,1,next_newline_char);
            all_tracked_files := SUBSTR( all_tracked_files,  next_newline_char+1 );
        END LOOP;
        RETURN ret;
    END list;

    FUNCTION run( custom_args args ) RETURN CLOB
    IS
        output_file CONSTANT VARCHAR2(250) := 'output'||'_'||TO_CHAR(SYSDATE,'YYYYMMDD_HH:MI:SS')||'_'||SYS_CONTEXT('USERENV', 'SESSIONID');

        forced_args CONSTANT git.args :=
            args(
              src_dir_path||git_wrapper.script_file
            , output_file
            , '--git-dir'   , src_dir_path||'.git'
            , '--work-tree' , src_dir_path
            );

        stdout CLOB;
    BEGIN
        DBMS_SCHEDULER.DROP_JOB('git_run');

        DBMS_SCHEDULER.CREATE_JOB
        ( job_name            => 'git_run'
        , job_type            => 'EXECUTABLE'
        , job_action          => git_wrapper.job_action
        , auto_drop           => TRUE
        , number_of_arguments => forced_args.COUNT+custom_args.COUNT
        );

        FOR i IN 1..forced_args.COUNT+custom_args.COUNT
        LOOP
            IF i <= forced_args.COUNT
            THEN DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE( 'git_run', i, forced_args(i));
            ELSE DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE( 'git_run', i, custom_args(i-forced_args.COUNT));
            END IF;
        END LOOP;

        DBMS_SCHEDULER.RUN_JOB('git_run');

        stdout := DBMS_XSLPROCESSOR.READ2CLOB(flocation => src_dir_name,fname => output_file);

        UTL_FILE.FREMOVE(src_dir_name,output_file||'_debug');
        UTL_FILE.FREMOVE(src_dir_name,output_file);

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
        RETURN git.run( git.args( 'add', src_filename( name,owner,type )));
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
        stdout := git.run( git.args( 'rm', src_filename( name,owner,type )));

        IF ora_dict_obj_type = 'PACKAGE'
        THEN stdout :=
              stdout || chr(10)
              || git.run( git.args( 'rm', src_filename( name,owner,type => 'PACKAGE BODY' )));
        END IF;

        RETURN stdout;
    END rm;

    PROCEDURE mute(ignored VARCHAR2) IS BEGIN NULL; END;
BEGIN
    mute(git.init());
END git;
