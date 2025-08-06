#!/bin/bash

# Configuration
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
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        table_name, 
        pg_size_pretty(pg_relation_size('openalex.' || table_name)) as size,
        (SELECT count(*) FROM openalex.\"works\") as works_rows,
        (SELECT count(*) FROM openalex.\"works_ids\") as works_ids_rows,
        (SELECT count(*) FROM openalex.\"works_authorships\") as works_authorships_rows,
        (SELECT count(*) FROM openalex.\"works_concepts\") as works_concepts_rows,
        (SELECT count(*) FROM openalex.\"works_referenced_works\") as works_referenced_works_rows,
        (SELECT count(*) FROM openalex.\"works_related_works\") as works_related_works_rows,
        (SELECT count(*) FROM openalex.\"works_open_access\") as works_open_access_rows,
        (SELECT count(*) FROM openalex.\"works_counts_by_year\") as works_counts_by_year_rows
    FROM 
        information_schema.tables 
    WHERE 
        table_schema = 'openalex' 
    ORDER BY 
        table_name;
    "
    
    echo ""
    echo "ACTIVE COPY OPERATIONS:"
    echo "---------------------------------------------------------------"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        pid, 
        now() - query_start AS duration, 
        state, 
        substring(query, 1, 80) AS query_preview
    FROM 
        pg_stat_activity 
    WHERE 
        query LIKE '%COPY%' AND
        state = 'active' 
    ORDER BY 
        duration DESC;
    "
    
    echo ""
    echo "OTHER ACTIVE DATABASE OPERATIONS:"
    echo "---------------------------------------------------------------"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        pid, 
        now() - query_start AS duration, 
        state, 
        substring(query, 1, 80) AS query_preview
    FROM 
        pg_stat_activity 
    WHERE 
        query NOT LIKE '%COPY%' AND
        state != 'idle' AND
        pid != pg_backend_pid()
    ORDER BY 
        duration DESC;
    "
    
    echo ""
    echo "SCREEN SESSIONS:"
    echo "---------------------------------------------------------------"
    screen -ls | grep -v "better_monitor"
    
    echo ""
    echo "LOADING PROGRESS CHECK:"
    echo "---------------------------------------------------------------"
    for table in works works_ids works_authorships works_concepts works_referenced_works works_related_works works_open_access works_counts_by_year; do
        screen -S "load_${table}" -Q echo > /dev/null
        if [ $? -eq 0 ]; then
            echo "${table}: Still loading"
        else
            echo "${table}: Completed or not started"
        fi
    done
    
    echo ""
    echo "- View a specific load: screen -r load_table_name"
    echo "- Detach from screen: Ctrl+A, then D"
    echo "- This monitor updates every 30 seconds"
    echo "- Press Ctrl+C to exit"
    
    sleep 30
done
