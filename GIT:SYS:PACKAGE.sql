CREATE OR REPLACE PACKAGE git
IS
    TYPE args IS VARRAY(40) OF VARCHAR2(400);
    PROCEDURE save   ( name VARCHAR2, owner VARCHAR2, type VARCHAR2, source CLOB );

    FUNCTION status RETURN CLOB;
    FUNCTION init   RETURN CLOB;
    FUNCTION reset  RETURN CLOB;
    FUNCTION commit ( message VARCHAR2 ) RETURN CLOB;
    FUNCTION add    ( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB;
    FUNCTION rm     ( name VARCHAR2, owner VARCHAR2, type VARCHAR2 ) RETURN CLOB;
    FUNCTION run    ( custom_args args ) RETURN CLOB;
END git;
