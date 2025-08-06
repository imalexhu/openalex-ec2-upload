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
