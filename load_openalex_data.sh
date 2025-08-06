#!/bin/bash

# Configuration
DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_PORT="5432"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

# Kill any existing screen sessions (just to be safe)
echo "Cleaning up any existing screen sessions..."
for session in $(screen -ls | grep -o '[0-9]*\.load_[a-z_]*'); do
    screen -X -S $session quit
done

# Disable indexes
echo "Disabling indexes..."
cat > disable_indexes.sql << 'INDEOSQL'
-- Drop indexes before loading data
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
DROP INDEX IF EXISTS openalex.works_open_access_work_id_idx;
DROP INDEX IF EXISTS openalex.works_counts_by_year_work_id_idx;
DROP INDEX IF EXISTS openalex.works_ids_work_id_idx;
DROP INDEX IF EXISTS openalex.works_ids_doi_idx;
INDEOSQL

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -f disable_indexes.sql

# Create index creation script for later
cat > enable_indexes.sql << 'INDEXSQL'
-- Recreate indexes after loading data
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
CREATE INDEX works_open_access_work_id_idx ON openalex.works_open_access (work_id);
CREATE INDEX works_counts_by_year_work_id_idx ON openalex.works_counts_by_year (work_id);
CREATE INDEX works_ids_work_id_idx ON openalex.works_ids (work_id);
CREATE INDEX works_ids_doi_idx ON openalex.works_ids (doi);
INDEXSQL

# Function to start a screen session for a table load
load_table_in_screen() {
    TABLE=$1
    CSV_FILE=$2
    COLS=$3
    SCREEN_NAME="load_$TABLE"
    
    # Create a script for this specific load
    LOAD_SCRIPT="/tmp/load_${TABLE}.sh"
    
    cat > $LOAD_SCRIPT << INNEREOF
#!/bin/bash
echo "Loading $TABLE from $CSV_FILE..."
echo "Started at: \$(date)"

# Print file size
echo "File size: \$(du -h $CSV_FILE | cut -f1)"

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "\\\\copy openalex.$TABLE $COLS from '$CSV_FILE' csv header;"

echo "$TABLE loaded successfully!"
echo "Completed at: \$(date)"
echo "Press Enter to exit this screen"
read
INNEREOF
    
    chmod +x $LOAD_SCRIPT
    
    # Start a new screen session for this table
    screen -dmS $SCREEN_NAME bash -c "$LOAD_SCRIPT"
    
    echo "Started loading $TABLE in screen session '$SCREEN_NAME'"
    echo "You can attach to this session with: screen -r $SCREEN_NAME"
    
    # Wait a bit to stagger the starts
    sleep 2
}

# Start loading all tables in separate screen sessions
echo "Starting data loading in screen sessions..."

# Start with smaller tables first
load_table_in_screen "works_counts_by_year" "csv-files/works_counts_by_year.csv" "(work_id, year, cited_by_count)"
load_table_in_screen "works_open_access" "csv-files/works_open_access.csv" "(work_id, is_oa, oa_status, oa_url)"
load_table_in_screen "works_ids" "csv-files/works_ids.csv" "(work_id, openalex, doi, mag, pmid, pmcid, arxiv, isbn13, isbn10, jstor)"
load_table_in_screen "works_authorships" "csv-files/works_authorships.csv" "(work_id, author_position, author_id, institution_id, raw_affiliation_string)"
load_table_in_screen "works" "csv-files/works.csv" "(id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext, cited_by_api_url, abstract_inverted_index, language, updated_date)"
load_table_in_screen "works_concepts" "csv-files/works_concepts.csv" "(work_id, concept_id, score)"
load_table_in_screen "works_referenced_works" "csv-files/works_referenced_works.csv" "(work_id, referenced_work_id)"
load_table_in_screen "works_related_works" "csv-files/works_related_works.csv" "(work_id, related_work_id)"

# Create monitoring script
cat > monitor_tables.sh << 'MONSQL'
#!/bin/bash
echo "Monitoring PostgreSQL tables..."
while true; do
    clear
    echo "Current time: $(date)"
    echo ""
    echo "Current table sizes:"
    echo "------------------------------------------------"
    PGPASSWORD=openalex psql -h openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com -U dbadmin -d openalex -c "SELECT table_name, pg_size_pretty(pg_total_relation_size('openalex.' || table_name)) as size, (SELECT count(*) FROM openalex.\"${table_name}\") as row_count FROM information_schema.tables WHERE table_schema = 'openalex' ORDER BY pg_total_relation_size('openalex.' || table_name) DESC;"
    echo ""
    echo "Active screens:"
    screen -ls
    echo ""
    echo "Press Ctrl+C to exit monitoring"
    sleep 60
done
MONSQL

chmod +x monitor_tables.sh

# Start monitoring in another screen session
screen -dmS monitor_tables bash -c "./monitor_tables.sh"

echo "All loading processes have been started in separate screen sessions."
echo ""
echo "To view the monitoring screen (recommended):"
echo "  screen -r monitor_tables"
echo ""
echo "To view a specific loading process:"
echo "  screen -r load_table_name"
echo ""
echo "To detach from any screen: Press Ctrl+A, then D"
echo ""
echo "To list all screen sessions:"
echo "  screen -ls"
echo ""
echo "After all loading is complete, run this to create indexes:"
echo "  PGPASSWORD=openalex psql -h openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com -U dbadmin -d openalex -f enable_indexes.sql"
echo ""
