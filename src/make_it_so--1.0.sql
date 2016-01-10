-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION make_it_so" to load this file. \quit

CREATE OR REPLACE FUNCTION make_relkind_to_text(char)
RETURNS text LANGUAGE SQL AS $$
    SELECT CASE $1
        WHEN 'r' THEN 'table'
        WHEN 'i' THEN 'index'
        WHEN 'S' THEN 'sequence'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized view'
        WHEN 'c' THEN 'composite type'
        WHEN 't' THEN 'TOAST table'
        WHEN 'f' THEN 'foreign table'
        ELSE 'unknown'
    END;
$$;

CREATE OR REPLACE FUNCTION make_table(text)
RETURNS bool LANGUAGE plpgsql AS $$
DECLARE
    k char;
BEGIN
    -- Lookup the relation with that name
    SELECT relkind FROM pg_class 
        WHERE relname = $1
        INTO k;
    
    -- The simple case: no relation of that name exists
    IF NOT FOUND THEN
        EXECUTE 'CREATE TABLE ' || quote_ident( $1 ) || ' ()';
        RETURN true;
    END IF;
    
    -- The harder cases: a relation of that name already exists.
    CASE k
        WHEN 'r' THEN
            -- Table already exists, nothing to do.
            RETURN false;
        WHEN 'v' THEN
            EXECUTE 'DROP VIEW ' || quote_ident( $1 ) || ' CASCADE';
        WHEN 'm' THEN
            EXECUTE 'DROP MATERIALIZED VIEW ' || quote_ident( $1 ) || ' CASCADE';
        ELSE
            RAISE EXCEPTION 'Table name conflict: %', $1
                USING DETAIL = 'The desired table name conflicts with a ' 
                || make_relkind_to_text(k)
                || ' of that name.';
    END CASE;
    
    EXECUTE 'CREATE TABLE ' || quote_ident( $1 ) || ' ()';
    RETURN true;
END
$$;
