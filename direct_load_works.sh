#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"
CSV_FILE="csv-files/works.csv"

echo "==== DIRECT LOADING OF WORKS TABLE ===="
echo "Started at: $(date)"
echo "This approach uses the psql client directly with proper connection settings"

# Create psql script
cat > load_works.psql << EOSQL
\timing on
\echo 'Loading works table...'
\copy openalex.works (id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date) from '${CSV_FILE}' csv header;
\echo 'Loading complete!'
EOSQL

# Run the script with psql directly
PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -f load_works.psql

RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "==== WORKS TABLE LOADED SUCCESSFULLY ===="
else
    echo "==== ERROR LOADING WORKS TABLE ===="
    echo "Error code: $RESULT"
fi

echo "Finished at: $(date)"
echo "Press Enter to close this window"
read
