#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

while true; do
    clear
    echo "=================================================="
    echo "          OPENALEX MINIMAL MONITOR"
    echo "             $(date)"
    echo "=================================================="
    
    echo ""
    echo "ACTIVE COPY OPERATIONS:"
    echo "--------------------------------------------------"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        pid, 
        substring(query, 1, 50) as query,
        state,
        now() - query_start as duration
    FROM 
        pg_stat_activity 
    WHERE 
        query LIKE '%COPY%' AND
        state = 'active'
    LIMIT 5;
    "
    
    echo ""
    echo "SCREEN SESSIONS:"
    echo "--------------------------------------------------"
    screen -ls | grep -v "minimal_monitor"
    
    echo ""
    echo "TABLE SIZE CHECK (ONE TABLE AT A TIME):"
    
    # Get table size for each table, one at a time to avoid overloading the DB
    for table in works works_ids works_authorships works_concepts works_referenced_works works_related_works works_open_access works_counts_by_year; do
        echo -n "Checking ${table}... "
        size=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_relation_size('openalex.${table}'));" 2>/dev/null | tr -d ' ' || echo "Error")
        
        if [ "$size" != "Error" ] && [ "$size" != "" ]; then
            echo "Size: $size"
            
            # Only try to count rows if the size is substantial
            if [ "$size" != "0bytes" ] && [ "$size" != "8192bytes" ]; then
                echo -n "  Row count sample (LIMIT 1): "
                PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM (SELECT 1 FROM openalex.\"${table}\" LIMIT 1) as t;" 2>/dev/null || echo "Error counting"
            fi
        else
            echo "Table not found or error checking size"
        fi
    done
    
    echo ""
    echo "- Press Ctrl+C to exit monitoring"
    echo "- This screen refreshes every 60 seconds"
    echo "- To view a loading process: screen -r load_table_name"
    
    sleep 60
done
