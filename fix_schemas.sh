#!/bin/bash

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

echo "=== Fixing Database Schemas ==="

# First, drop all foreign key constraints to avoid dependency issues
echo "Dropping foreign key constraints..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DO \$\$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT 
            tc.constraint_name, tc.table_name
        FROM 
            information_schema.table_constraints AS tc 
        JOIN 
            information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
        WHERE 
            tc.constraint_type = 'FOREIGN KEY' AND
            tc.table_schema = '$SCHEMA'
    ) LOOP
        EXECUTE 'ALTER TABLE $SCHEMA.' || quote_ident(r.table_name) || ' DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;
END \$\$;
"

# Drop and recreate tables with correct schemas
echo "Recreating tables with proper schemas..."

# works table
echo "Fixing works table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works CASCADE;
CREATE TABLE $SCHEMA.works (
    id TEXT PRIMARY KEY,
    doi TEXT,
    title TEXT,
    display_name TEXT,
    publication_date DATE,
    publication_year INT,
    type TEXT,
    open_access TEXT,
    citation_count INT,
    referenced_works_count INT,
    is_retracted BOOLEAN,
    is_paratext BOOLEAN,
    created_date TEXT
);
"

# works_ids table
echo "Fixing works_ids table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_ids CASCADE;
CREATE TABLE $SCHEMA.works_ids (
    work_id TEXT,
    openalex TEXT,
    doi TEXT,
    mag TEXT,
    pmid TEXT,
    pmcid TEXT
);
"

# works_authorships table
echo "Fixing works_authorships table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_authorships CASCADE;
CREATE TABLE $SCHEMA.works_authorships (
    work_id TEXT,
    author_position TEXT,
    author_id TEXT,
    institution_id TEXT,
    raw_affiliation_string TEXT
);
"

# works_concepts table
echo "Fixing works_concepts table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_concepts CASCADE;
CREATE TABLE $SCHEMA.works_concepts (
    work_id TEXT,
    concept_id TEXT,
    score FLOAT
);
"

# works_referenced_works table
echo "Fixing works_referenced_works table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_referenced_works CASCADE;
CREATE TABLE $SCHEMA.works_referenced_works (
    work_id TEXT,
    referenced_work_id TEXT
);
"

# works_related_works table
echo "Fixing works_related_works table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_related_works CASCADE;
CREATE TABLE $SCHEMA.works_related_works (
    work_id TEXT,
    related_work_id TEXT
);
"

# works_open_access table
echo "Fixing works_open_access table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_open_access CASCADE;
CREATE TABLE $SCHEMA.works_open_access (
    work_id TEXT,
    is_oa BOOLEAN,
    oa_status TEXT,
    oa_url TEXT
);
"

# works_counts_by_year table
echo "Fixing works_counts_by_year table..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_counts_by_year CASCADE;
CREATE TABLE $SCHEMA.works_counts_by_year (
    work_id TEXT,
    year INT,
    cited_by_count INT
);
"

echo "=== Schema fixes completed ==="
