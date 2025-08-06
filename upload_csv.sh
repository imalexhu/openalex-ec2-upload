#!/bin/bash
# Script to upload a CSV file directly to a database table
# Usage: ./upload_csv.sh <csv_file> <table_name>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <csv_file> <table_name>"
    exit 1
fi

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

# Input parameters
CSV_FILE="$1"
TABLE_NAME="$2"
LOG_FILE="logs/${TABLE_NAME}_upload.log"

mkdir -p logs

# Check file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File not found - $CSV_FILE"
    exit 1
fi

# Check table exists
table_exists=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "
    SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = '$SCHEMA' AND table_name = '$TABLE_NAME');
")

if [[ ! $table_exists =~ t ]]; then
    echo "Error: Table $SCHEMA.$TABLE_NAME does not exist"
    exit 1
fi

echo "Starting upload of $CSV_FILE to $SCHEMA.$TABLE_NAME at $(date)" | tee -a "$LOG_FILE"
echo "File size: $(du -h $CSV_FILE | cut -f1)" | tee -a "$LOG_FILE"

# Use psql's COPY command with CSV format
start_time=$(date +%s)

# Use a more robust copy command with error handling
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 -c "
-- Set larger work memory for this operation
SET work_mem = '256MB';
-- Turn off synchronous commit for better performance
SET synchronous_commit TO OFF;
-- Use COPY command with CSV format
\copy $SCHEMA.$TABLE_NAME FROM '$CSV_FILE' WITH (FORMAT csv, HEADER, DELIMITER ',', QUOTE '\"', ESCAPE '\\');
"

upload_status=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

# Calculate duration in a human-readable format
hours=$((duration / 3600))
minutes=$(( (duration % 3600) / 60 ))
seconds=$((duration % 60))

if [ $upload_status -eq 0 ]; then
    echo "Upload completed successfully at $(date)" | tee -a "$LOG_FILE"
else
    echo "Upload FAILED at $(date)" | tee -a "$LOG_FILE"
fi

echo "Upload took ${hours}h ${minutes}m ${seconds}s" | tee -a "$LOG_FILE"

# Verify data
row_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM $SCHEMA.$TABLE_NAME;")
row_count=$(echo $row_count | tr -d ' ')

table_size=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.$TABLE_NAME'));")
table_size=$(echo $table_size | tr -d ' ')

echo "Row count: $row_count" | tee -a "$LOG_FILE"
echo "Table size: $table_size" | tee -a "$LOG_FILE"

echo "=== Upload complete ==="
