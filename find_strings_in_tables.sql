create or replace PROCEDURE find_string_in_tables (
    p_string_to_search IN VARCHAR2,
    p_datatype IN VARCHAR2 DEFAULT 'VARCHAR2'
) IS
    TYPE table_info_type IS RECORD (
        table_name   VARCHAR2(200),
        column_name  VARCHAR2(200)
    );

    TYPE table_info_table IS TABLE OF table_info_type;
    table_info_list table_info_table;

    exists_v       NUMBER;
    string_to_search_v VARCHAR2(200) := UPPER(p_string_to_search);

    CURSOR cur_tables IS
        SELECT table_name, column_name
        FROM all_tab_columns
        WHERE data_type LIKE '%' || p_datatype || '%'
        AND data_length >= LENGTH(string_to_search_v)
        AND table_name NOT LIKE 'BIN$%'
        AND OWNER = 'someowner';
BEGIN
    OPEN cur_tables;
    LOOP
        FETCH cur_tables BULK COLLECT INTO table_info_list LIMIT 100;

        EXIT WHEN table_info_list.COUNT = 0;

        FOR i IN 1 .. table_info_list.COUNT LOOP
            -- Print the table and column currently being searched
            dbms_output.put_line('Searching in table: ' || table_info_list(i).table_name || 
                                 ' column: ' || table_info_list(i).column_name);

            -- Execute the query and check if the string exists
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM someowner.' || table_info_list(i).table_name ||
                              ' WHERE UPPER(' || table_info_list(i).column_name || ') LIKE :1' 
                              INTO exists_v USING '%' || string_to_search_v || '%';

            IF exists_v > 0 THEN
                dbms_output.put_line('String: ' || string_to_search_v || ' Exists in someowner.' || 
                                     table_info_list(i).table_name || ':' || table_info_list(i).column_name);
            ELSE
                -- Print when the string is not found in the current table/column
                dbms_output.put_line('String not found in table: ' || table_info_list(i).table_name || 
                                     ' column: ' || table_info_list(i).column_name);
            END IF;
        END LOOP;
    END LOOP;

    CLOSE cur_tables;
END find_string_in_tables;
/


CREATE OR REPLACE PROCEDURE find_strings_in_tables (
    p_strings_to_search IN VARCHAR2,    -- comma-separated search strings
    p_datatype IN VARCHAR2 DEFAULT 'VARCHAR2'
) IS
    TYPE table_info_type IS RECORD (
        table_name   VARCHAR2(200),
        column_name  VARCHAR2(200)
    );
    
    TYPE table_info_table IS TABLE OF table_info_type;
    table_info_list table_info_table;

    exists_v       NUMBER;
    search_string  VARCHAR2(4000);
    
    CURSOR cur_tables IS
        SELECT table_name, column_name
        FROM all_tab_columns
        WHERE data_type LIKE '%' || p_datatype || '%'
        AND table_name NOT LIKE 'BIN$%'
        AND OWNER = 'someowner'; --make sure this owner is the owner of the table you are looking for, and replace where ever someowner is referenced in this file
    
    -- Declare a variable to hold multiple search strings
    v_strings SYS.ODCIVARCHAR2LIST; 

    -- Function to split the input string by a delimiter
    FUNCTION split_strings(p_string IN VARCHAR2, p_delimiter IN VARCHAR2)
        RETURN SYS.ODCIVARCHAR2LIST IS
        v_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
        v_start NUMBER := 1;
        v_end   NUMBER;
    BEGIN
        v_end := INSTR(p_string, p_delimiter, v_start);
        WHILE v_end > 0 LOOP
            v_list.EXTEND;
            v_list(v_list.COUNT) := SUBSTR(p_string, v_start, v_end - v_start);
            v_start := v_end + LENGTH(p_delimiter);
            v_end := INSTR(p_string, p_delimiter, v_start);
        END LOOP;

        IF v_start <= LENGTH(p_string) THEN
            v_list.EXTEND;
            v_list(v_list.COUNT) := SUBSTR(p_string, v_start);
        END IF;

        RETURN v_list;
    END split_strings;

BEGIN
    -- Split the input strings into a list
    v_strings := split_strings(p_strings_to_search, ',');

    OPEN cur_tables;
    LOOP
        FETCH cur_tables BULK COLLECT INTO table_info_list LIMIT 100;

        EXIT WHEN table_info_list.COUNT = 0;

        FOR i IN 1 .. table_info_list.COUNT LOOP
            -- Iterate through the list of strings to search
            FOR j IN 1 .. v_strings.COUNT LOOP
                search_string := UPPER(TRIM(v_strings(j)));
                
                -- Print which table and column is currently being searched
                dbms_output.put_line('Searching for "' || search_string || '" in table: ' || 
                                     table_info_list(i).table_name || 
                                    ' column: ' || table_info_list(i).column_name);

                -- Execute the query and check if the string exists (with wildcard support)
                EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM someowner.' || table_info_list(i).table_name ||
                                  ' WHERE UPPER(' || table_info_list(i).column_name || ') LIKE :1'
                                  INTO exists_v USING search_string;

                IF exists_v > 0 THEN
                    dbms_output.put_line('String: "' || search_string || '" Exists in someowner.' || 
                                         table_info_list(i).table_name || ':' || table_info_list(i).column_name);
                ELSE
                    dbms_output.put_line('String: "' || search_string || '" Not found in someowner.' || 
                                         table_info_list(i).table_name || ':' || table_info_list(i).column_name);
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;

    CLOSE cur_tables;
END find_strings_in_tables;
/


create or replace PROCEDURE find_and_replace_strings_in_tables (
    p_search_string IN VARCHAR2,      -- Search string (with optional wildcards)
    p_replace_string IN VARCHAR2,     -- Replace string
    p_datatype IN VARCHAR2 DEFAULT 'VARCHAR2'
) IS
    TYPE table_info_type IS RECORD (
        table_name   VARCHAR2(200),
        column_name  VARCHAR2(200)
    );

    TYPE table_info_table IS TABLE OF table_info_type;
    table_info_list table_info_table;

    exists_v       NUMBER;
    search_string  VARCHAR2(4000);
    replace_string VARCHAR2(4000) := p_replace_string;

    CURSOR cur_tables IS
        SELECT table_name, column_name
        FROM all_tab_columns
        WHERE data_type LIKE '%' || p_datatype || '%'
        AND table_name NOT LIKE 'BIN$%'
        AND OWNER = 'someowner';
BEGIN
    -- Ensure the search string is in uppercase (since we're performing case-insensitive searches)
    search_string := UPPER(p_search_string);

    OPEN cur_tables;
    LOOP
        FETCH cur_tables BULK COLLECT INTO table_info_list LIMIT 100;

        EXIT WHEN table_info_list.COUNT = 0;

        FOR i IN 1 .. table_info_list.COUNT LOOP
            -- Print which table and column is currently being searched
            dbms_output.put_line('Searching for "' || search_string || '" in table: ' || 
                                 table_info_list(i).table_name || 
                                 ' column: ' || table_info_list(i).column_name);

            -- Check if the search string exists
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM someowner.' || table_info_list(i).table_name ||
                              ' WHERE UPPER(' || table_info_list(i).column_name || ') LIKE :1'
                              INTO exists_v USING '%' || search_string || '%';

            IF exists_v > 0 THEN
                -- Print a message when the string is found and being replaced
                dbms_output.put_line('Found "' || search_string || '" in someowner.' || 
                                     table_info_list(i).table_name || 
                                     '.' || table_info_list(i).column_name || 
                                     ' - Replacing with "' || replace_string || '"');

                -- Replace the search string with the replace string
                EXECUTE IMMEDIATE 'UPDATE someowner.' || table_info_list(i).table_name ||
                                  ' SET ' || table_info_list(i).column_name || 
                                  ' = REPLACE(UPPER(' || table_info_list(i).column_name || '), :1, :2)'
                                  USING search_string, replace_string;

                -- Commit after each replacement to avoid long transactions
                COMMIT;

                -- Print success message
                dbms_output.put_line('Replaced in table: ' || table_info_list(i).table_name ||
                                     ' column: ' || table_info_list(i).column_name);
            ELSE
                -- Print when the string is not found in the current table/column
                dbms_output.put_line('String: "' || search_string || '" Not found in someowner.' || 
                                     table_info_list(i).table_name || ':' || table_info_list(i).column_name);
            END IF;
        END LOOP;
    END LOOP;

    CLOSE cur_tables;
END find_and_replace_strings_in_tables;
/
