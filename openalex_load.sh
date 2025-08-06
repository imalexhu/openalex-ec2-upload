#!/bin/bash

# Configuration
DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

echo "Starting OpenAlex database loading process..."

# Step 1: Drop indexes to speed up loading
echo "Dropping indexes..."
cat > drop_indexes.sql << 'INDEXSQL'
DROP INDEX IF EXISTS openalex.works_id_idx;
DROP INDEX IF EXISTS openalex.works_doi_idx;
DROP INDEX IF EXISTS openalex.works_publication_year_idx;
DROP INDEX IF EXISTS openalex.works_type_idx;
DROP INDEX IF EXISTS openalex.works_cited_by_count_idx;
DROP INDEX IF EXISTS openalex.works_authorships_work_id_idx;
DROP INDEX IF EXISTS openalex.works_authorships_author_id_idx;
DROP INDEX IF EXISTS openalex.works_concepts_work_id_idx;
DROP INDEX IF EXISTS openalex.works_concepts_concept_id_idx;
DROP INDEX IF EXISTS openalex.works_referenced_works_work_id_idx;
DROP INDEX IF EXISTS openalex.works_related_works_work_id_idx;
DROP INDEX IF EXISTS openalex.works_open_access_is_oa_idx;
DROP INDEX IF EXISTS openalex.works_counts_by_year_work_id_idx;
DROP INDEX IF EXISTS openalex.works_ids_work_id_idx;
DROP INDEX IF EXISTS openalex.works_ids_doi_idx;
INDEXSQL

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -f drop_indexes.sql

# Step 2: Create a script to recreate indexes later
cat > create_indexes.sql << 'INDEXSQL'
CREATE INDEX works_id_idx ON openalex.works (id);
CREATE INDEX works_doi_idx ON openalex.works (doi);
CREATE INDEX works_publication_year_idx ON openalex.works (publication_year);
CREATE INDEX works_type_idx ON openalex.works (type);
CREATE INDEX works_cited_by_count_idx ON openalex.works (cited_by_count);
CREATE INDEX works_authorships_work_id_idx ON openalex.works_authorships (work_id);
CREATE INDEX works_authorships_author_id_idx ON openalex.works_authorships (author_id);
CREATE INDEX works_concepts_work_id_idx ON openalex.works_concepts (work_id);
CREATE INDEX works_concepts_concept_id_idx ON openalex.works_concepts (concept_id);
CREATE INDEX works_referenced_works_work_id_idx ON openalex.works_referenced_works (work_id);
CREATE INDEX works_related_works_work_id_idx ON openalex.works_related_works (work_id);
CREATE INDEX works_open_access_is_oa_idx ON openalex.works_open_access (is_oa);
CREATE INDEX works_counts_by_year_work_id_idx ON openalex.works_counts_by_year (work_id);
CREATE INDEX works_ids_work_id_idx ON openalex.works_ids (work_id);
CREATE INDEX works_ids_doi_idx ON openalex.works_ids (doi);
INDEXSQL

# Step 3: Define function to start loading a table in a screen session
start_loading() {
    TABLE=$1
    CSV_FILE=$2
    COLUMNS=$3
    SCREEN_NAME="load_$TABLE"
    
    SCRIPT_FILE="/tmp/load_${TABLE}.sh"
    
    cat > $SCRIPT_FILE << LOADSCRIPT
#!/bin/bash
echo "=== Loading $TABLE ==="
echo "CSV File: $CSV_FILE"
echo "Started at: \$(date)"
echo "File size: \$(du -h $CSV_FILE | cut -f1)"

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "\\\\copy openalex.$TABLE $COLUMNS from '$CSV_FILE' csv header;"

echo ""
echo "=== $TABLE loading complete ==="
echo "Finished at: \$(date)"
echo "Rows loaded: \$(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c \"SELECT count(*) FROM openalex.$TABLE;\")"
echo ""
echo "Press Enter to close this screen"
read
LOADSCRIPT
    
    chmod +x $SCRIPT_FILE
    screen -dmS $SCREEN_NAME $SCRIPT_FILE
    echo "Started loading $TABLE (screen session: $SCREEN_NAME)"
}

# Step 4: Create monitoring script
cat > monitor.sh << 'MONITORSCRIPT'
#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

check_table_status() {
    TABLE=$1
    CSV_FILE=$2
    
    # Get CSV file size
    CSV_SIZE=$(du -h $CSV_FILE 2>/dev/null | cut -f1)
    if [ -z "$CSV_SIZE" ]; then CSV_SIZE="N/A"; fi
    
    # Get table size
    TABLE_SIZE=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_relation_size('openalex.$TABLE'));" | tr -d ' ')
    if [ -z "$TABLE_SIZE" ]; then TABLE_SIZE="0 bytes"; fi
    
    # Get row count
    ROW_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM openalex.$TABLE;" | tr -d ' ')
    if [ -z "$ROW_COUNT" ]; then ROW_COUNT="0"; fi
    
    # Is loading active?
    LOADING=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM pg_stat_activity WHERE query LIKE '%COPY%$TABLE%' AND state='active';" | tr -d ' ')
    if [ "$LOADING" -gt "0" ]; then
        STATUS="LOADING"
    else
        if [ "$ROW_COUNT" -gt "0" ]; then
            STATUS="LOADED"
        else
            STATUS="PENDING"
        fi
    fi
    
    printf "%-25s | %-10s | %-12s | %12s | %s\n" "$TABLE" "$STATUS" "$TABLE_SIZE" "$ROW_COUNT" "$CSV_SIZE"
}

while true; do
    clear
    echo "===================================================================="
    echo "              OPENALEX DATABASE LOADING MONITOR"
    echo "                    $(date)"
    echo "===================================================================="
    echo ""
    echo "TABLE STATUS:"
    echo "--------------------------------------------------------------------"
    printf "%-25s | %-10s | %-12s | %12s | %s\n" "TABLE" "STATUS" "DB SIZE" "ROWS" "CSV SIZE"
    echo "--------------------------------------------------------------------"
    check_table_status "works" "csv-files/works.csv"
    check_table_status "works_ids" "csv-files/works_ids.csv"
    check_table_status "works_authorships" "csv-files/works_authorships.csv"
    check_table_status "works_concepts" "csv-files/works_concepts.csv"
    check_table_status "works_referenced_works" "csv-files/works_referenced_works.csv"
    check_table_status "works_related_works" "csv-files/works_related_works.csv"
    check_table_status "works_open_access" "csv-files/works_open_access.csv"
    check_table_status "works_counts_by_year" "csv-files/works_counts_by_year.csv"
    echo ""
    
    echo "ACTIVE DATABASE OPERATIONS:"
    echo "--------------------------------------------------------------------"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        pid, 
        now() - query_start AS duration, 
        state, 
        substring(query, 1, 50) AS query_preview
    FROM 
        pg_stat_activity 
    WHERE 
        state != 'idle' 
    ORDER BY 
        duration DESC;
    "
    
    echo ""
    echo "SCREEN SESSIONS:"
    echo "--------------------------------------------------------------------"
    screen -ls
    echo ""
    echo "Instructions:"
    echo "  - To view a specific loading screen: screen -r load_table_name"
    echo "  - To detach from a screen: Ctrl+A, then D"
    echo "  - This monitor updates every 30 seconds"
    echo "  - Press Ctrl+C to exit monitoring"
    sleep 30
done
MONITORSCRIPT

chmod +x monitor.sh

# Step 5: Start loading all tables
echo "Starting to load tables..."
start_loading "works_counts_by_year" "csv-files/works_counts_by_year.csv" "(work_id, year, cited_by_count)"
start_loading "works_open_access" "csv-files/works_open_access.csv" "(work_id, is_oa, oa_status, oa_url)"
start_loading "works_ids" "csv-files/works_ids.csv" "(work_id, openalex, doi, mag, pmid, pmcid, arxiv, isbn13, isbn10, jstor)"
start_loading "works_authorships" "csv-files/works_authorships.csv" "(work_id, author_position, author_id, institution_id, raw_affiliation_string)"
start_loading "works" "csv-files/works.csv" "(id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date)"
start_loading "works_concepts" "csv-files/works_concepts.csv" "(work_id, concept_id, score)"
start_loading "works_referenced_works" "csv-files/works_referenced_works.csv" "(work_id, referenced_work_id)"
start_loading "works_related_works" "csv-files/works_related_works.csv" "(work_id, related_work_id)"

# Step 6: Start monitoring screen
screen -dmS monitor ./monitor.sh
echo ""
echo "All loading processes started!"
echo ""
echo "To view the monitoring screen (recommended):"
echo "  screen -r monitor"
echo ""
echo "When all loads are complete, run this to create indexes:"
echo "  PGPASSWORD=openalex psql -h openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com -U dbadmin -d openalex -f create_indexes.sql"
echo ""
