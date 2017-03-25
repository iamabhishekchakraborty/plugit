PACKAGE plugit
AUTHID CURRENT_USER
IS
    PROCEDURE store( address VARCHAR2, message VARCHAR2 );
    FUNCTION review( address VARCHAR2 ) RETURN CLOB;
END plugit;
