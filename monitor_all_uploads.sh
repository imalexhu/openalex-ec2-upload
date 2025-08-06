#!/bin/bash
# Script to monitor the progress of all table uploads

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

# ANSI color codes for better visualization
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Clear screen function
clear_screen() {
    printf "\033c"
}

# Function to format large numbers with commas
format_number() {
    printf "%'d" $1 2>/dev/null || echo $1
}

# Function to check upload status
get_upload_status() {
    local table=$1
    
    # Check if screen session exists
    if screen -list | grep -q "upload_$table"; then
        echo -e "${GREEN}Running${NC}"
    else
        # Check if upload completed
        if [ -f "logs/${table}_upload.log" ] && grep -q "Upload completed successfully" "logs/${table}_upload.log"; then
            echo -e "${BLUE}Completed${NC}"
        elif [ -f "logs/${table}_upload.log" ]; then
            echo -e "${YELLOW}Stopped${NC}"
        else
            echo -e "${RED}Not Started${NC}"
        fi
    fi
}

# Function to get last log message
get_last_log() {
    local table=$1
    local log_file="logs/${table}_upload.log"
    
    if [ -f "$log_file" ]; then
        tail -5 "$log_file" | grep -v "^$" | tail -1 | cut -c 1-50
    else
        echo "-"
    fi
}

# Function to get upload progress
estimate_progress() {
    local table=$1
    local log_file="logs/${table}_upload.log"
    
    if [ -f "$log_file" ]; then
        local start_time=$(grep -m 1 "Starting upload" "$log_file" | awk -F'at ' '{print $2}')
        local total_size=$(grep -m 1 "File size:" "$log_file" | awk '{print $3}')
        
        # If upload is still running, calculate elapsed time
        if screen -list | grep -q "upload_$table"; then
            local now=$(date +%s)
            local start_seconds=$(date -d "$start_time" +%s 2>/dev/null || echo 0)
            
            if [ $start_seconds -gt 0 ]; then
                local elapsed=$((now - start_seconds))
                local hours=$((elapsed / 3600))
                local minutes=$(( (elapsed % 3600) / 60 ))
                
                echo "${hours}h ${minutes}m elapsed"
            else
                echo "In progress"
            fi
        elif grep -q "Upload took" "$log_file"; then
            # If completed, show total time
            grep "Upload took" "$log_file" | tail -1 | sed 's/Upload took //'
        else
            echo "-"
        fi
    else
        echo "-"
    fi
}

# Main monitoring loop
while true; do
    clear_screen
    
    # Display header
    echo -e "${BOLD}=== OpenAlex Database Upload Monitor ===${NC}"
    echo "Database: $DB_HOST"
    echo "Updated: $(date)"
    echo
    
    # Get database stats
    DB_SIZE=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));")
    ACTIVE_CONNS=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';")
    
    echo -e "${BOLD}Database Size:${NC} $(echo $DB_SIZE | tr -d ' ')"
    echo -e "${BOLD}Active Connections:${NC} $(echo $ACTIVE_CONNS | tr -d ' ')"
    echo
    
    # Table header
    printf "${BOLD}%-20s %-12s %-15s %-15s %-12s %-30s${NC}\n" "Table" "Status" "Row Count" "Size" "Time" "Latest Activity"
    printf "%-20s %-12s %-15s %-15s %-12s %-30s\n" "--------------------" "------------" "---------------" "---------------" "------------" "------------------------------"
    
    # List of tables to monitor
    TABLES=("works" "works_ids" "works_authorships" "works_concepts" "works_referenced_works" "works_related_works" "works_open_access" "works_counts_by_year")
    
    # Display table status
    for table in "${TABLES[@]}"; do
        # Get status
        status=$(get_upload_status "$table")
        
        # Get row count
        row_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "
            SELECT reltuples::bigint FROM pg_class WHERE relname = '$table' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = '$SCHEMA');
        ")
        row_count=$(echo $row_count | tr -d ' ')
        if [ -z "$row_count" ] || [ "$row_count" = "0" ]; then
            # Try direct count if estimate is 0
            row_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM $SCHEMA.$table;" 2>/dev/null || echo "0")
            row_count=$(echo $row_count | tr -d ' ')
        fi
        
        # Format row count
        if [ -n "$row_count" ] && [ "$row_count" != "0" ]; then
            row_count=$(format_number $row_count)
        else
            row_count="0"
        fi
        
        # Get table size
        table_size=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.$table'));")
        table_size=$(echo $table_size | tr -d ' ')
        
        # Get progress time
        progress_time=$(estimate_progress "$table")
        
        # Get last log entry
        last_log=$(get_last_log "$table")
        
        # Print table row
        printf "%-20s %-12b %-15s %-15s %-12s %-30s\n" \
               "$table" "$status" "$row_count" "$table_size" "$progress_time" "$last_log"
    done
    
    echo
    echo "Active screen sessions:"
    screen -ls | grep "upload_" || echo "No active upload sessions"
    
    echo
    echo "Press Ctrl+C to exit this monitor"
    
    # Update every 5 seconds
    sleep 5
done
