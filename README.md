# SonarQube metrics
[SonarQube Dashboard](https://sonarqube.com/dashboard?id=plugit_plsql_under_git)

# PLUGIT - PL/sql Under GIT
PL/SQL utilities to Git version control your Oracle source code

**Warning - These utilities are currently in development and aren't ready for production.**

# Current features:
 - Auto initialize Git repository and required scripts (or call git.init on-demand)
 - Uses Bash shell scripts (to get Git stdout/stderr messages)
 - Convention over configuration
 - Automatically save new sources to Git repository
 - Plugit expect to find Git binaries in /usr/bin/git (easily customizable)
 - Naive interface to several Git commands, such as:
   - commit (By default, Plugit uses current USERNAME and HOSTNAME as the commiter info)
   - status
   - reset
   - add
   - rm
 - Call any Git command via the git.run function

# Future work:
 - Add support for other Shells and Operating Systems
 - Provide a mechanism to easily clone an existing repository
 - Think of a better repository structure and filenaming conventions
 - Implement some strategy to automatically and effectively compile sources from a cloned repository
 - Research strategies for pushing/pulling from a remote repository
 - Syncing multiple databases using a Git workflow such as branching/merging/fetching...

# Installation
```sql
CREATE DIRECTORY VERSION_CONTROL AS '/path/to/your/desired/repository/path';
```
Compile these sources in your desired schema.
If you want your users to be able to manually call Git commands such as commit, rm, etc. grant them permissions to the GIT package.

# Proposed Workflow
These utilities are not inherently designed to allow multi-user collaboration in a shared database.
Future work will include the development of a series of companion utilities that should solve related problems such as:
 - Multi-user development
 - Continuous deployment
 - 3rd party services?
