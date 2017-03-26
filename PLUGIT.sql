create or replace PACKAGE plugit
AUTHID CURRENT_USER
IS
    debug CLOB;

    PROCEDURE store( address VARCHAR2, message VARCHAR2 );
    FUNCTION review( address VARCHAR2 ) RETURN CLOB;
END plugit;

