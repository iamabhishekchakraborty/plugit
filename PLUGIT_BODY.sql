PACKAGE BODY plugit
IS
    SUBTYPE dirname IS all_directories.directory_name%TYPE;
    SUBTYPE dirpath IS all_directories.directory_path%TYPE;
    SUBTYPE repo_address IS VARCHAR2(300);

    TYPE tracked_objects  IS TABLE OF all_objects.object_id%TYPE;
    TYPE tracked_repo IS RECORD (
      address     repo_address
    , directory   dirname
    , object_ids  tracked_objects
    );

    TYPE tracked_repos IS TABLE OF tracked_repo INDEX BY repo_address;
    managed_repos tracked_repos;

    TYPE args IS TABLE OF VARCHAR2(400);

    slash       CONSTANT VARCHAR2(1)  := CASE WHEN INSTR(UPPER(dbms_utility.port_string),'WIN') > 0 THEN '\' ELSE '/' END;
    git_wrapper CONSTANT VARCHAR2(30) := 'git_wrapper';
    git_binary  CONSTANT dirpath      := 'git';

    FUNCTION shell(directory dirname) RETURN VARCHAR2
    IS  script_code CLOB;
        shell_path  dirpath;
        linux_shell CONSTANT CLOB:=
'#!/bin/sh
currentDir="$(dirname "${BASH_SOURCE[0]}")"
cd "$currentDir"
outputFile=$1
workingDir=$2
binCommand=$3
debugText="$@"
shift
shift
shift
outputText=$("$binCommand" "$@" 2>'||chr(38)||'1)
echo "$outputText" > "$workingDir""$outputFile" 
echo "$debugText"  > "$workingDir""$outputFile"_debug
';
    BEGIN
        CASE WHEN INSTR(UPPER(dbms_utility.port_string),'WIN') > 0
        THEN NULL;-- TODO
        ELSE
            script_code := linux_shell;
            shell_path := '/bin/sh';
        END CASE;

        dbms_xslprocessor.clob2file( script_code, directory, git_wrapper );
        RETURN shell_path;
    END shell;

    PROCEDURE track (
        objects   IN tracked_objects
      , address   VARCHAR2
      , directory dirname DEFAULT 'VERSION_CONTROL'
    )
    IS  cur_repo_address repo_address;
        object_conflicts tracked_objects;
    BEGIN
        IF managed_repos.EXISTS( address )
        THEN RAISE_APPLICATION_ERROR( -20001, 'Multiple definitions for the repo: '||address );
        END IF;

        IF managed_repos.COUNT > 0
        THEN
            cur_repo_address := managed_repos.FIRST;
            LOOP
                EXIT WHEN cur_repo_address IS NULL;

                object_conflicts := managed_repos( cur_repo_address ).object_ids MULTISET INTERSECT objects;
                IF object_conflicts.COUNT > 0
                THEN RAISE_APPLICATION_ERROR( -20001, 'Tracking the same object in multiple repos is not allowed.' );
                END IF;

                cur_repo_address := managed_repos.NEXT(cur_repo_address);
            END LOOP;
        END IF;
        managed_repos(address).address    := address;
        managed_repos(address).directory  := directory;
        managed_repos(address).object_ids := objects;
    END track;

    FUNCTION object_by_id( object_id#in all_objects.object_id%TYPE ) RETURN all_objects%ROWTYPE
    IS  object all_objects%ROWTYPE;
    BEGIN
        SELECT *
        INTO object
        FROM all_objects
        WHERE object_id = object_id#in;

        RETURN object;
    END object_by_id;

    FUNCTION path( dirname dirname ) RETURN dirpath
    IS  ret dirpath;
    BEGIN
        SELECT directory_path
        INTO ret
        FROM all_directories
        WHERE directory_name = dirname;

        RETURN ret;
    END path;

    FUNCTION run( directory dirname, arg_list args, debug IN OUT CLOB ) RETURN CLOB
    IS  output_file   CONSTANT dirpath := 'output'||'_'||TO_CHAR(SYSDATE,'YYYYMMDD_HH:MI:SS')||'_'||SYS_CONTEXT('USERENV', 'SESSIONID');
        src_dir_path  CONSTANT dirpath := path( directory );
        all_args      CONSTANT args :=
            args( src_dir_path||git_wrapper
                , output_file
                , src_dir_path ) MULTISET UNION arg_list;

        stdout CLOB;
 
        custom_job_name CONSTANT VARCHAR2(20) := 'custom_os_command';
        job_doesnt_exist EXCEPTION;
        PRAGMA EXCEPTION_INIT( job_doesnt_exist, -27475 );
    BEGIN
        BEGIN
            DBMS_SCHEDULER.DROP_JOB(custom_job_name);
        EXCEPTION WHEN job_doesnt_exist
        THEN debug := debug || CHR(10) || 'The job doesn''t exists. We don''t need to drop it';
        END;

        DBMS_SCHEDULER.CREATE_JOB
        ( job_name            => custom_job_name
        , job_type            => 'EXECUTABLE'
        , job_action          =>  shell(directory)
        , auto_drop           => TRUE
        , number_of_arguments => all_args.COUNT
        );

        FOR i IN 1..all_args.COUNT
        LOOP  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE( custom_job_name, i, all_args(i));
              debug := debug || ' ' || all_args(i);
        END LOOP;

        DBMS_SCHEDULER.RUN_JOB(custom_job_name);

        stdout := DBMS_XSLPROCESSOR.READ2CLOB(flocation => directory,fname => output_file);

        RETURN stdout;
    END run;

    PROCEDURE run( directory dirname, arg_list args, debug IN OUT CLOB )
    IS  dummy CLOB;
    BEGIN
        dummy := run( directory, arg_list, debug );
    END run;

    FUNCTION repo_path( repo tracked_repo ) RETURN dirpath
    IS  normRepo      CONSTANT VARCHAR2(200) := repo.address;
        src_dir_name  CONSTANT dirname := repo.directory;
        src_dir_path  CONSTANT dirpath := path( src_dir_name )||REPLACE(normRepo,slash,'_');
    BEGIN
        RETURN src_dir_path;
    END repo_path;

    FUNCTION run_git( repo tracked_repo, custom_args args, debug IN OUT CLOB ) RETURN CLOB
    IS  src_dir_path  CONSTANT dirpath := repo_path(repo);
        all_args      CONSTANT args := 
            args( git_binary
                , '--git-dir'
                , src_dir_path||'/.git'
                , '--work-tree', src_dir_path ) MULTISET UNION custom_args;
    BEGIN
        RETURN run( repo.directory, all_args, debug );
    END run_git;

    PROCEDURE run_git( repo tracked_repo, custom_args args, debug IN OUT CLOB )
    IS  dummy CLOB;
    BEGIN
        dummy := run_git( repo, custom_args, debug );
    END run_git;

    PROCEDURE init( repo tracked_repo, debug IN OUT CLOB )
    IS  src_dir_path  CONSTANT dirpath := repo_path(repo);
    BEGIN
        run( repo.directory, args('mkdir','-p',src_dir_path), debug );
        run_git( repo, args('init'), debug);
    END init;

    FUNCTION get_source( object_id#in all_objects.object_id%TYPE ) RETURN CLOB
    IS  ret CLOB;
    BEGIN
        FOR i IN (SELECT src.text
                  FROM all_objects obj
                  JOIN all_source src
                  ON  obj.owner       = src.owner
                  AND obj.object_name = src.name
                  AND obj.object_type = src.type
                  WHERE object_id = object_id#in
                  ORDER BY line ASC)
        LOOP
            ret := ret||i.text;
        END LOOP;
        RETURN ret;
    END get_source;

    PROCEDURE save( repo tracked_repo, object_id all_objects.object_id%TYPE, debug IN OUT CLOB )
    IS  object        CONSTANT all_objects%ROWTYPE := object_by_id( object_id );
        filename      CONSTANT dirpath := object.object_name;
        working_dir   CONSTANT dirpath := path( repo.directory );
        source_path   CONSTANT dirpath := working_dir||slash||filename;
        destin_path   CONSTANT dirpath := repo_path(repo)||slash||object.owner||slash||object.object_type;
    BEGIN
        run( repo.directory, args('mkdir','-p',destin_path), debug );
        dbms_xslprocessor.clob2file( get_source( object_id )||CHR(10), repo.directory, filename );
        run( repo.directory, args('mv',source_path,destin_path), debug );
    END save;

    PROCEDURE add( repo tracked_repo, object_id all_objects.object_id%TYPE, debug IN OUT CLOB )
    IS  src_dir_path  CONSTANT dirpath := repo_path(repo);
        object      CONSTANT all_objects%ROWTYPE := object_by_id( object_id );
    BEGIN
        run_git( repo, args( 'add', src_dir_path||slash||object.owner||slash||object.object_type||slash||object.object_name), debug );
    END add;

    PROCEDURE git_commit( repo tracked_repo, message VARCHAR2, debug IN OUT CLOB )
    IS
    BEGIN
        IF repo.object_ids.COUNT > 0
        THEN
            FOR cur_object IN repo.object_ids.FIRST..repo.object_ids.LAST
            LOOP
                add( repo, repo.object_ids(cur_object), debug );
            END LOOP;
        END IF;

        run_git( repo,
          args
          ( '-c', 'user.name=' ||USER
          , '-c', 'user.email='||UTL_INADDR.get_host_name
          , 'commit'
          , '-m', message
          )
          , debug
        );
    END git_commit;

    FUNCTION commit( address VARCHAR2, message VARCHAR2 ) RETURN CLOB
    IS  debug CLOB;
        repo tracked_repo := managed_repos( address );
    BEGIN
        git_commit( repo, message, debug );
        RETURN debug;
    END commit;

    PROCEDURE store( address VARCHAR2, message VARCHAR2, debug IN OUT CLOB )
    IS  repo tracked_repo := managed_repos(address);
    BEGIN
        init( repo, debug );

        IF repo.object_ids.COUNT > 0
        THEN
            FOR cur_object IN repo.object_ids.FIRST..repo.object_ids.LAST
            LOOP
                save( repo, repo.object_ids(cur_object), debug );
            END LOOP;
        END IF;
        git_commit( repo, message, debug );
    END store;

    PROCEDURE store( address VARCHAR2, message VARCHAR2 )
    IS  debug CLOB;
    BEGIN
        store( address, message, debug );
    END store;

    FUNCTION temp_branch( repo tracked_repo, empty BOOLEAN, debug IN OUT CLOB ) RETURN VARCHAR2
    IS  cur_object_properties all_objects%ROWTYPE;
        branch_name CONSTANT VARCHAR2(500) := 'TEMP_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDD_HH24MISS_FF4');
    BEGIN
        debug := debug || run_git( repo, args( 'checkout', '--orphan', branch_name ), debug );
        IF NVL(empty,FALSE)
        THEN debug := debug || run_git( repo, args( 'reset', '--hard' ), debug );
        END IF;
        RETURN branch_name;
    END temp_branch;

    FUNCTION current_branch_name( repo tracked_repo, debug IN OUT CLOB ) RETURN VARCHAR2
    IS  num_commits NUMBER;
        branch_name VARCHAR2(500);
    BEGIN
        branch_name := REPLACE(run_git( repo, args( 'symbolic-ref', '--short', 'HEAD' ), debug ),CHR(10));
        num_commits := TO_NUMBER(REPLACE(run_git( repo, args( 'rev-list', '--count', 'HEAD' ), debug ),CHR(10)));
        RETURN branch_name;
    EXCEPTION WHEN VALUE_ERROR
              THEN RAISE_APPLICATION_ERROR( -20001, 'The branch '||branch_name||' doesn''t have any COMMIT. You must COMMIT at least once before calling this function.' );
    END current_branch_name;

    FUNCTION review( address VARCHAR2, debug IN OUT CLOB ) RETURN CLOB
    IS  cur_object_properties all_objects%ROWTYPE;
        curr_branch VARCHAR2(500);
        temp1_branch VARCHAR2(500);
        temp2_branch VARCHAR2(500);
        ret CLOB;
        repo tracked_repo := managed_repos(address);
    BEGIN
        curr_branch  := current_branch_name( repo, debug );
        temp1_branch := temp_branch( repo, empty => FALSE, debug => debug );
        debug := debug || run_git( repo, args( 'add', '-A' ), debug );
        git_commit ( repo, 'EXACT Copy of "master" working directory', debug );

        temp2_branch := temp_branch( repo, empty => TRUE, debug => debug );
        store( repo.address, 'EXACT Copy of objects in DATABASE', debug );

        ret := run_git( repo, args( 'diff', '--name-status', temp1_branch||'..'||temp2_branch ), debug );

        debug := debug || ret;
        run_git( repo, args( 'checkout', curr_branch ), debug );
        run_git( repo, args( 'checkout', temp1_branch, '--', '*' ), debug );
        run_git( repo, args( 'branch', '-D', temp1_branch ), debug );
        run_git( repo, args( 'branch', '-D', temp2_branch ), debug );

        RETURN ret;
    END review;

    FUNCTION review( address VARCHAR2 ) RETURN CLOB
    IS  debug CLOB;
    BEGIN
        RETURN review( address, debug );
    END review;
BEGIN
    DECLARE  list_of_objects tracked_objects;
    BEGIN
        SELECT object_id
        BULK COLLECT INTO list_of_objects
        FROM all_objects
        WHERE object_name = 'PLUGIT';

        track( list_of_objects,'https://github.com/fejnartal/plugit' );
    END;
END plugit;


