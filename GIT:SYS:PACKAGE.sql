create or replace PACKAGE git
IS
    TYPE files  IS TABLE OF VARCHAR2(400);
    TYPE args   IS VARRAY(40) OF VARCHAR2(400);

    PROCEDURE save  ( name VARCHAR2, owner VARCHAR2, type VARCHAR2, source CLOB );
    PROCEDURE load  ( filename VARCHAR2 );
    FUNCTION  list RETURN git.files;

    FUNCTION status RETURN CLOB;
    FUNCTION init   RETURN CLOB;
    FUNCTION reset  RETURN CLOB;
    FUNCTION commit ( message VARCHAR2 ) RETURN CLOB;
    FUNCTION add    ( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB;
    FUNCTION rm     ( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB;
    FUNCTION run    ( custom_args args ) RETURN CLOB;
END git;
