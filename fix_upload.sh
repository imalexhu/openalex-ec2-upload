#!/bin/bash
# Direct upload script for CSV files

if [ $# -ne 2 ]; then
    echo "Usage: $0 <csv_file> <table_name>"
    exit 1
fi

CSV_FILE="$1"
TABLE_NAME="$2"
SCHEMA="openalex"
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
LOG_FILE="logs/${TABLE_NAME}_upload.log"

mkdir -p logs

# Check file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File not found: $CSV_FILE"
    exit 1
fi

echo "Starting upload of $CSV_FILE to $SCHEMA.$TABLE_NAME at $(date)" | tee -a "$LOG_FILE"
echo "File size: $(du -h $CSV_FILE | cut -f1)" | tee -a "$LOG_FILE"

# Create a temporary SQL script file
SQL_FILE="/tmp/upload_${TABLE_NAME}.sql"

cat > "$SQL_FILE" << EOL
-- Temporary SQL script to load data
SET work_mem = '256MB';
SET synchronous_commit TO OFF;
\\copy $SCHEMA.$TABLE_NAME FROM '$CSV_FILE' CSV HEADER;
EOL

# Execute the SQL script
start_time=$(date +%s)
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_FILE" 2>&1 | tee -a "$LOG_FILE"
status=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

# Calculate duration
hours=$((duration / 3600))
minutes=$((duration % 3600 / 60))
seconds=$((duration % 60))

# Report results
if [ $status -eq 0 ]; then
    echo "Upload completed successfully at $(date)" | tee -a "$LOG_FILE"
else
    echo "Upload FAILED at $(date)" | tee -a "$LOG_FILE"
fi

echo "Upload took ${hours}h ${minutes}m ${seconds}s" | tee -a "$LOG_FILE"

# Get row count
row_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $SCHEMA.$TABLE_NAME;")
row_count=$(echo "$row_count" | tr -d ' ')

# Get table size
table_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.$TABLE_NAME'));")
table_size=$(echo "$table_size" | tr -d ' ')

echo "Row count: $row_count" | tee -a "$LOG_FILE"
echo "Table size: $table_size" | tee -a "$LOG_FILE"

# Clean up temp file
rm "$SQL_FILE"

echo "=== Upload complete ==="
