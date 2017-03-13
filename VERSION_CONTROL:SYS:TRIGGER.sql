CREATE OR REPLACE TRIGGER version_control
BEFORE CREATE OR DROP
ON DATABASE
DECLARE
    FUNCTION source_clob RETURN CLOB
    IS
        source_fragmnent ora_name_list_t;
        source_code CLOB;
    BEGIN
        FOR i IN 1..ora_sql_txt(source_fragmnent)
        LOOP source_code := source_code || source_fragmnent(i);
        END LOOP;
        source_code := SUBSTR( source_code, 1, DBMS_LOB.getLength(source_code)-1 );

        RETURN source_code;
    END source_clob;

    PROCEDURE mute( ignored VARCHAR2 ) IS BEGIN NULL; END mute;
BEGIN
   CASE ora_sysevent
    WHEN 'DROP'
    THEN mute(git.rm(
            name  => ora_dict_obj_name
          , owner => ora_dict_obj_owner
          , type  => ora_dict_obj_type
        ));
    WHEN 'CREATE'
    THEN git.save(
            name  => ora_dict_obj_name
          , owner => ora_dict_obj_owner
          , type  => ora_dict_obj_type
          , source=> source_clob
        );
    END CASE;
END version_control;
