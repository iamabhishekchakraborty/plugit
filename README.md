# SonarQube metrics
[SonarQube Dashboard](https://sonarqube.com/dashboard?id=plugit_plsql_under_git)

# PLUGIT - PL/sql Under GIT
PL/SQL utilities to Git version control your Oracle source code

**Warning - These utilities are currently in development and aren't ready for production.**

# Current features:
 - Fully OracleXE 11g compatible
 - Auto initialize Git repository
 - Uses Bash shell scripts (to get Git stdout/stderr messages)
 - Convention over configuration
 - Query-based method to specify "versionable" objects
 - Support for multiple repositories

# Future work:
 - Primary goal: Use Plugit to version control its own source
 - Allow to easily customize objects_filename/filepath
 - Opt for a "Fixed schema" model in which objects are stored prefixed thier schema?
 - Allow calling "store" with a customized list of objects (instead of all tracked objects)
 - Improve performance
 - Test older versions of OracleDB for compatibility issues
 - Add support for other Shells and Operating Systems
 - Implement cloning/restoring functionality 
 - Implement some strategy to automatically and effectively compile sources from a cloned repository
 - Research strategies for pushing/pulling from a remote repository (public+private ssh key?)
 - Syncing multiple databases using a Git workflow such as branching/merging/fetching...
 - Message internationalization

# Installation:
```sql
CREATE DIRECTORY VERSION_CONTROL AS '/path/to/your/desired/repository/path';
```
Compile these sources in your desired schema.

# Configuration
This tool favours a Query-based approach for specifying the "versionable" objects.
The source code below, is an example to allow every single object inside the "SAMPLE" schema to be version-controlled.
```sql
    DECLARE  list_of_objects tracked_objects;
    BEGIN
        SELECT object_id
        BULK COLLECT INTO list_of_objects
        FROM all_objects
        WHERE owner = 'SAMPLE';

        track( list_of_objects,'https://your/repo/url/here.git' );
    END;
```

Place this code in the [INITIALIZATION SECTION](http://awads.net/wp/2005/06/29/oracle-plsql-package-initialization/) of the PLUGIT package.

The idea behind this strategy is that, when deploying to production, ONLY objects matched by these queries will be accepted and compiled.

When a new developer joins your team and clones your custom version of this repository, he/she will also be cloning these Query-Selectors.
Therefore he/she will be forced to follow team-conventions regarding naming, allowed schemas, types, etc. 

# Object locking and other strategies:
These utilities are not designed to allow multi-user collaboration in a shared database.

Moreover, I'd advise against this practice as I strongly believe that there are better solutions to the problem

(Using some version control system together with some automatic provisining tool to allow every single developer to work on his/her own copy of the database).

Future work to this tool will include the development of a series of companion utilities to try to solve related problems such as:
 - Unit testing
 - Conditional Debugging/Logging
 - Multi-user development
 - Continuous deployment
 - Integration with 3rd party services?
