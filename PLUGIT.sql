create or replace PACKAGE plugit
AUTHID CURRENT_USER
IS
    FUNCTION log RETURN CLOB;
    FUNCTION store ( address VARCHAR2, message VARCHAR2 ) RETURN CLOB;
    FUNCTION review( address VARCHAR2 ) RETURN CLOB;
END plugit;

