#!/bin/bash

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

echo "=== Updating Table Schemas to Match CSV Structure ==="

# First, stop all uploads
echo "Stopping all upload processes..."
for session in $(screen -ls | grep upload_ | awk '{print $1}'); do
    screen -S $session -X quit
done
sleep 2

# Drop and recreate works table
echo "Updating works table schema..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works CASCADE;
CREATE TABLE $SCHEMA.works (
    id TEXT PRIMARY KEY,
    doi TEXT,
    title TEXT,
    display_name TEXT,
    publication_year INT,
    publication_date DATE,
    type TEXT,
    cited_by_count INT,
    is_retracted BOOLEAN,
    is_paratext BOOLEAN,
    cited_by_api_url TEXT,
    abstract_inverted_index TEXT,
    language TEXT,
    updated_date TEXT
);
"

# Drop and recreate works_ids table
echo "Updating works_ids table schema..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_ids CASCADE;
CREATE TABLE $SCHEMA.works_ids (
    work_id TEXT,
    openalex TEXT,
    doi TEXT,
    mag TEXT,
    pmid TEXT,
    pmcid TEXT,
    arxiv TEXT,
    isbn13 TEXT,
    isbn10 TEXT,
    jstor TEXT
);
"

# Define all tables that need to be fixed
echo "Creating the rest of the schemas if they don't exist..."

# works_authorships
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_authorships CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_authorships (
    work_id TEXT,
    author_position TEXT,
    author_id TEXT,
    institution_id TEXT,
    raw_affiliation_string TEXT
);
"

# works_concepts
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_concepts CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_concepts (
    work_id TEXT,
    concept_id TEXT,
    score FLOAT
);
"

# works_referenced_works
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_referenced_works CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_referenced_works (
    work_id TEXT,
    referenced_work_id TEXT
);
"

# works_related_works
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_related_works CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_related_works (
    work_id TEXT,
    related_work_id TEXT
);
"

# works_open_access
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_open_access CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_open_access (
    work_id TEXT,
    is_oa BOOLEAN,
    oa_status TEXT,
    oa_url TEXT
);
"

# works_counts_by_year
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS $SCHEMA.works_counts_by_year CASCADE;
CREATE TABLE IF NOT EXISTS $SCHEMA.works_counts_by_year (
    work_id TEXT,
    year INT,
    cited_by_count INT
);
"

echo "=== Table schemas updated successfully ==="
echo "You can now restart the uploads with ./start_upload_simple.sh"
