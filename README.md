# NOT READY FOR USE! (work in progress)

# Make-It-So — a declarative DDL for Postgresql

*"Make it so, number one!"* —Jean-Luc Picard

Mold your database to your will. I'm porting my psql-tools.sh collection
of shell scripts to a faster, more robust, more DRY collection of functions
written in plpgsql, and I'm just bold enough to make them publicly available
as a bona-fide Postgresql extension.

## Installation:
1. Copy the .sql and .control files to /usr/share/postgresql/9.3/extension
(or whatever it is on your system).
2. Open `psql`
3. and run `CREATE EXTENSION make_it_so`

## Functions:
make_table(name text)
- Ensure a table of that name exists. Will destroy views and materialized views in its way, but not indexes, TOAST tables, etc.

## Future functions:
 
make_it_so(definitions json)

- Form all the database / schema / user / table / view / function from their definitions

### Form columns
make_column_so(table regclass, definitions json)
- name string (required)
- type string (required)
- default string|null (optional)
- is_not_null bool (optional)
- is_unique bool (optional)
- is_index bool (optional)

### Form tables
make_table_so(definitions json)
- sets/unsets table attributes
- recursively calls make_column_so()

### Form views
make_view_so(definitions json)
- name string (required)
- definition string (required)

### Form functions
make_function_so(definition json)
- name string (required)
- language string (required)
- is_cachable bool (optional)
- is_volatile bool (optional)
- is_null_if_null_input bool (optional)
- definition string (required)
