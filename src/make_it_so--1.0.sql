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

CREATE OR REPLACE FUNCTION make_column(tbl text, col text, typ text)
RETURNS bool LANGUAGE plpgsql AS $$
BEGIN
    -- See if column exists
    IF EXISTS( SELECT 1 FROM pg_attribute 
                WHERE attname = col 
                  AND attrelid = tbl::regclass 
                  AND NOT attisdropped
                  AND attnum > 0
                  ) THEN
        RETURN false;
    END IF;
    
    -- Create column
    EXECUTE 'ALTER TABLE '||quote_ident( tbl )||' ADD COLUMN '||quote_ident( col )||' '||typ;
    RETURN true;
END
$$;



CREATE OR REPLACE FUNCTION make_table_so(data json)
RETURNS bool LANGUAGE plpgsql AS $$
<<this>>
DECLARE
    uuid uuid;
    new_name text;
    old_name text;
    oid oid;
    changed bool := false;
BEGIN
    uuid := data->>'uuid';
    new_name := data->>'name';
    -- Retrieve any existing data for this row.
    SELECT relname, _inventory.oid FROM _inventory WHERE _inventory.uuid = this.uuid INTO old_name, oid;
    -- Create inventory row if missing.
    IF NOT FOUND THEN INSERT INTO _inventory (uuid) VALUES (this.uuid); END IF;
    -- Rename table if names differ
    IF oid IS NOT NULL AND new_name != old_name THEN
        EXECUTE 'ALTER TABLE '||quote_ident( old_name )||' RENAME TO '||quote_ident( new_name );
        changed := true;
    END IF;
    -- Create or get an existing table if OID missing
    IF oid IS NULL THEN
        changed := make_table(new_name);
        oid := new_name::regclass::oid;
    END IF;
    -- Update inventory
    UPDATE _inventory
        SET relname = this.new_name
          , oid     = this.oid
        WHERE _inventory.uuid = this.uuid
    ;
    -- TODO: Recursively apply changes to subcomponents of the table.
    
    RETURN changed;
END this
$$;


-- Now we get to use ourself, lol.
DO $$
BEGIN
    PERFORM make_table('_inventory');
    PERFORM make_column('_inventory','relname','text');
    PERFORM make_column('_inventory','oid','int');
    PERFORM make_column('_inventory','uuid','uuid');
END
$$;
-- CREATE TABLE _inventory ("relname" text, "oid" int, "uuid" uuid);

/* Placeholder
INSERT INTO _inventory (
SELECT relname, oid FROM pg_class WHERE relkind='r'
AND relowner = (SELECT usesysid FROM pg_user WHERE usename = current_user)
);
*/