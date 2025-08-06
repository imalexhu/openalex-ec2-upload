#!/bin/bash

# Configuration
DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

#------------------------------------------------------
# STEP 1: DROP INDEXES
#------------------------------------------------------
echo "===== DROPPING INDEXES ====="
PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
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
"

#------------------------------------------------------
# STEP 2: OPTIMIZE POSTGRESQL SETTINGS
#------------------------------------------------------
echo "===== OPTIMIZING POSTGRESQL SETTINGS ====="
PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
SET statement_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET tcp_keepalives_idle = 60;
SET tcp_keepalives_interval = 10;
SET tcp_keepalives_count = 10;
"

#------------------------------------------------------
# STEP 3: START DATA LOADING
#------------------------------------------------------
echo "===== STARTING PARALLEL DATA LOADING ====="

# Function to start a loading screen
start_loading() {
    TABLE=$1
    CSV_FILE=$2
    COLUMNS=$3
    
    SCRIPT_FILE="/tmp/load_${TABLE}.sh"
    
    # Create loading script
    cat > $SCRIPT_FILE << LOADSCRIPT
#!/bin/bash

echo "=== LOADING ${TABLE} ==="
echo "File: ${CSV_FILE}"
echo "Size: \$(du -h ${CSV_FILE} | cut -f1)"
echo "Started at: \$(date)"

# Run COPY command with optimized settings
PGPASSWORD=${DB_PASSWORD} psql -h ${DB_ENDPOINT} -U ${DB_USER} -d ${DB_NAME} -c "
SET statement_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET tcp_keepalives_idle = 60;
SET tcp_keepalives_interval = 10;
SET tcp_keepalives_count = 10;
\\copy openalex.${TABLE} ${COLUMNS} from '${CSV_FILE}' csv header;
"

RESULT=\$?
if [ \$RESULT -eq 0 ]; then
    echo "=== ${TABLE} LOADED SUCCESSFULLY ==="
    echo "Finished at: \$(date)"
    echo "Row count: \$(PGPASSWORD=${DB_PASSWORD} psql -h ${DB_ENDPOINT} -U ${DB_USER} -d ${DB_NAME} -t -c \"SELECT count(*) FROM openalex.${TABLE}\")"
else
    echo "=== ERROR LOADING ${TABLE} ==="
    echo "Error code: \$RESULT"
    echo "Check the PostgreSQL logs for details"
fi

echo "Press Enter to close this window"
read
LOADSCRIPT
    
    chmod +x $SCRIPT_FILE
    
    # Start screen session
    screen -dmS "load_${TABLE}" $SCRIPT_FILE
    echo "Started loading ${TABLE} (screen: load_${TABLE})"
}

# Start loading each table
start_loading "works_counts_by_year" "csv-files/works_counts_by_year.csv" "(work_id, year, cited_by_count)"
start_loading "works_open_access" "csv-files/works_open_access.csv" "(work_id, is_oa, oa_status, oa_url)"
start_loading "works_ids" "csv-files/works_ids.csv" "(work_id, openalex, doi, mag, pmid, pmcid, arxiv, isbn13, isbn10, jstor)"
start_loading "works_authorships" "csv-files/works_authorships.csv" "(work_id, author_position, author_id, institution_id, raw_affiliation_string)"
start_loading "works" "csv-files/works.csv" "(id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date)"
start_loading "works_concepts" "csv-files/works_concepts.csv" "(work_id, concept_id, score)"
start_loading "works_referenced_works" "csv-files/works_referenced_works.csv" "(work_id, referenced_work_id)"
start_loading "works_related_works" "csv-files/works_related_works.csv" "(work_id, related_work_id)"

#------------------------------------------------------
# STEP 4: CREATE MONITORING SCREEN
#------------------------------------------------------
echo "===== CREATING MONITORING SCREEN ====="

# Create monitoring script
cat > simple_monitor.sh << 'MONSCRIPT'
#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

while true; do
    clear
    echo "==============================================================="
    echo "                OPENALEX LOADING MONITOR"
    echo "                  $(date)"
    echo "==============================================================="
    
    echo ""
    echo "TABLE SIZES AND ROW COUNTS:"
    echo "---------------------------------------------------------------"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "
    SELECT 
        table_name, 
        pg_size_pretty(pg_relation_size('openalex.' || table_name)) as size,
        (SELECT count(*) FROM openalex.\"${table_name}\") as rows
    FROM 
        information_schema.tables 
    WHERE 
        table_schema = 'openalex' 
    ORDER BY 
        table_name;
    "
    
    echo ""
    echo "ACTIVE DATABASE OPERATIONS:"
    echo "---------------------------------------------------------------"
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
    echo "---------------------------------------------------------------"
    screen -ls | grep -v "simple_monitor"
    
    echo ""
    echo "- View a specific load: screen -r load_table_name"
    echo "- Detach from screen: Ctrl+A, then D"
    echo "- This monitor updates every 30 seconds"
    echo "- Press Ctrl+C to exit"
    
    sleep 30
done
MONSCRIPT

chmod +x simple_monitor.sh
screen -dmS simple_monitor ./simple_monitor.sh

#------------------------------------------------------
# STEP 5: CREATE INDEX SCRIPT FOR LATER
#------------------------------------------------------
echo "===== CREATING INDEX SCRIPT ====="

cat > create_indexes.sh << 'INDEXSCRIPT'
#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

echo "===== CREATING INDEXES ====="
echo "Started at: $(date)"

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
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
"

echo "===== INDEXES CREATED ====="
echo "Finished at: $(date)"
INDEXSCRIPT

chmod +x create_indexes.sh

#------------------------------------------------------
# STEP 6: COMPLETION MESSAGE
#------------------------------------------------------
echo ""
echo "===== PROCESS STARTED SUCCESSFULLY ====="
echo ""
echo "To view the monitor (recommended):"
echo "  screen -r simple_monitor"
echo ""
echo "To view a specific loading process:"
echo "  screen -r load_[table_name]"
echo "  (e.g., screen -r load_works)"
echo ""
echo "After all loads complete, run this to create indexes:"
echo "  ./create_indexes.sh"
echo ""
echo "All loading processes are now running in parallel"
echo "This terminal can be closed without affecting the process"
