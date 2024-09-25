SET SERVEROUTPUT ON SIZE 10000000000;                                      
BEGIN                                      
   find_strings_in_tables('something%,%moreonsomething_','VARCHAR2')  ;      
   find_string_in_tables('something','VARCHAR2')  ;   
   --commit;
END;

