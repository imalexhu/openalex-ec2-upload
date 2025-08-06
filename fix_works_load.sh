#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"
CSV_FILE="csv-files/works.csv"

echo "=== LOADING works (fixed) ==="
echo "File: $CSV_FILE"
echo "Size: $(du -h $CSV_FILE | cut -f1)"
echo "Started at: $(date)"

# Method 1: Use COPY command directly (SQL command)
PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
SET statement_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET tcp_keepalives_idle = 60;
SET tcp_keepalives_interval = 10;
SET tcp_keepalives_count = 10;
COPY openalex.works (id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date) FROM '$CSV_FILE' CSV HEADER;
"

RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "=== works LOADED SUCCESSFULLY ==="
    echo "Finished at: $(date)"
    echo "Row count: $(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM openalex.works;")"
else
    echo "=== ERROR LOADING works ==="
    echo "Error code: $RESULT"
    echo ""
    echo "Trying alternative method..."
    
    # Method 2: Use \copy meta-command (psql client command)
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME << EOC
\timing on
\copy openalex.works (id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date) from '$CSV_FILE' csv header;
EOC
    
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "=== works LOADED SUCCESSFULLY (with alternative method) ==="
        echo "Finished at: $(date)"
        echo "Row count: $(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM openalex.works;")"
    else
        echo "=== ERROR LOADING works (alternative method also failed) ==="
        echo "Error code: $RESULT"
    fi
fi

echo "Press Enter to close this window"
read
