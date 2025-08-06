#!/bin/bash
# monitor_uploads.sh - Script to monitor the progress of all table uploads

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"
LOGS_DIR="logs"

# ANSI color codes for better visualization
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Clear screen and move cursor to top-left
clear_screen() {
    printf "\033c"
}

# Define table configurations (same as in start_uploads.sh)
TABLES=(
    "works"
    "works_ids"
    "works_authorships"
    "works_concepts"
    "works_referenced_works"
    "works_related_works"
    "works_open_access"
    "works_counts_by_year"
)

# Function to check if a screen session exists
screen_exists() {
    screen -list | grep -q "upload_$1"
    return $?
}

# Function to get screen session status
get_screen_status() {
    local table=$1
    local screen_name="upload_$table"
    
    if screen_exists "$table"; then
        echo -e "${GREEN}Running${NC}"
    else
        # Check if log file exists with completion
        if grep -q "Upload completed" "$LOGS_DIR/${table}_upload.log" 2>/dev/null; then
            echo -e "${BLUE}Completed${NC}"
        elif [ -f "$LOGS_DIR/${table}_upload.log" ]; then
            echo -e "${YELLOW}Stopped${NC}"
        else
            echo -e "${RED}Not Started${NC}"
        fi
    fi
}

# Function to get table row count
get_row_count() {
    local table=$1
    count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM $SCHEMA.$table;" 2>/dev/null)
    if [ $? -eq 0 ]; then
        count=$(echo $count | tr -d ' ')
        printf "%'d" $count 2>/dev/null || echo $count
    else
        echo "Error"
    fi
}

# Function to get table size
get_table_size() {
    local table=$1
    size=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.$table'));" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo $size | tr -d ' '
    else
        echo "Error"
    fi
}

# Function to get latest log message
get_latest_log() {
    local table=$1
    local log_file="$LOGS_DIR/${table}_upload.log"
    
    if [ -f "$log_file" ]; then
        tail -3 "$log_file" | grep -v "^$" | head -1 | cut -c -50
    else
        echo "-"
    fi
}

# Function to estimate progress for running uploads
get_progress() {
    local table=$1
    local log_file="$LOGS_DIR/${table}_upload.log"
    
    if [ -f "$log_file" ]; then
        # Try to find progress information in the log
        if grep -q "Progress:" "$log_file"; then
            grep "Progress:" "$log_file" | tail -1 | cut -d':' -f2 | sed 's/^[ \t]*//'
        elif grep -q "pv" "$log_file"; then
            # Try to extract progress from pv output
            grep "pv" "$log_file" | tail -1 | grep -o '[0-9]\+%' | tail -1 || echo "In progress"
        else
            echo "In progress"
        fi
    else
        echo "-"
    fi
}

# Main display loop
while true; do
    clear_screen
    
    # Display header
    echo -e "${BOLD}=== OpenAlex Database Upload Monitor ===${NC}"
    echo "Database: $DB_HOST"
    echo "Updated: $(date)"
    echo
    
    # Display database stats
    DB_SIZE=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
    ACTIVE_CONNS=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null)
    
    echo -e "${BOLD}Database Size:${NC} $(echo $DB_SIZE | tr -d ' ')"
    echo -e "${BOLD}Active Connections:${NC} $(echo $ACTIVE_CONNS | tr -d ' ')"
    echo
    
    # Display current uploads table
    printf "${BOLD}%-20s %-12s %-15s %-12s %-15s %-30s${NC}\n" "Table" "Status" "Row Count" "Size" "Progress" "Latest Activity"
    printf "%-20s %-12s %-15s %-12s %-15s %-30s\n" "--------------------" "------------" "---------------" "------------" "---------------" "------------------------------"
    
    for table in "${TABLES[@]}"; do
        status=$(get_screen_status "$table")
        row_count=$(get_row_count "$table")
        table_size=$(get_table_size "$table")
        progress=$(get_progress "$table")
        latest_log=$(get_latest_log "$table")
        
        printf "%-20s %-12b %-15s %-12s %-15s %-30s\n" \
               "$table" "$status" "$row_count" "$table_size" "$progress" "$latest_log"
    done
    
    echo
    echo "Active screen sessions:"
    screen -ls | grep "upload_" || echo "No active upload sessions"
    
    echo
    echo "Press Ctrl+C to exit this monitor"
    
    # Update every 5 seconds
    sleep 5
done
