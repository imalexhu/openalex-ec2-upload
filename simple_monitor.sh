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
