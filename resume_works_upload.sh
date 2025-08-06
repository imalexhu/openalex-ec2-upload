#!/bin/bash
# Script to resume the works table upload from where it failed

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"
WORKS_CSV="csv-files/works.csv"
LOG_FILE="logs/works_upload.log"

mkdir -p logs

# The upload failed at line 107253970, so we'll resume from the next line
RESUME_LINE=107253971

echo "=== Resuming Works Table Upload from Line $RESUME_LINE ===" | tee -a "$LOG_FILE"
echo "Start time: $(date)" | tee -a "$LOG_FILE"

# Check if file exists
if [ ! -f "$WORKS_CSV" ]; then
    echo "Error: Works CSV file not found: $WORKS_CSV" | tee -a "$LOG_FILE"
    exit 1
fi

# Get file info
echo "Getting file info..." | tee -a "$LOG_FILE"
FILE_SIZE=$(du -h "$WORKS_CSV" | cut -f1)
TOTAL_LINES=$(wc -l < "$WORKS_CSV")
REMAINING_LINES=$((TOTAL_LINES - RESUME_LINE + 1))
echo "File size: $FILE_SIZE" | tee -a "$LOG_FILE"
echo "Total lines: $TOTAL_LINES" | tee -a "$LOG_FILE"
echo "Resuming from line $RESUME_LINE (approximately $((RESUME_LINE*100/TOTAL_LINES))% complete)" | tee -a "$LOG_FILE"
echo "Remaining lines to process: $REMAINING_LINES" | tee -a "$LOG_FILE"

# Create temporary file with header + remaining lines
TEMP_CSV="/tmp/works_resume.csv"
echo "Creating temporary CSV with header + remaining lines..." | tee -a "$LOG_FILE"

# Extract header line
head -1 "$WORKS_CSV" > "$TEMP_CSV"

# Append the remaining lines starting from RESUME_LINE
echo "Extracting remaining lines (this may take a while)..." | tee -a "$LOG_FILE"
tail -n +$RESUME_LINE "$WORKS_CSV" >> "$TEMP_CSV"

# Verify the temp file
TEMP_SIZE=$(du -h "$TEMP_CSV" | cut -f1)
TEMP_LINES=$(wc -l < "$TEMP_CSV")
echo "Temporary file created: $TEMP_SIZE, $TEMP_LINES lines" | tee -a "$LOG_FILE"

# Create SQL script for the upload
SQL_FILE="/tmp/resume_works_upload.sql"
cat > "$SQL_FILE" << EOL
-- Optimize PostgreSQL settings for bulk loading
SET work_mem = '512MB';
SET maintenance_work_mem = '1GB';
SET synchronous_commit TO OFF;
SET temp_buffers = '256MB';
-- Load the data
\\copy $SCHEMA.works FROM '$TEMP_CSV' CSV HEADER;
EOL

# Start the upload
echo "Starting upload at $(date)..." | tee -a "$LOG_FILE"
start_time=$(date +%s)

PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_FILE" 2>&1 | tee -a "$LOG_FILE"
upload_status=$?

end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(( (duration % 3600) / 60 ))
seconds=$((duration % 60))

# Check upload status
if [ $upload_status -eq 0 ]; then
    echo "Upload completed successfully in ${hours}h ${minutes}m ${seconds}s" | tee -a "$LOG_FILE"
else
    echo "Error during upload. Check the logs for details." | tee -a "$LOG_FILE"
    # Clean up temporary files
    rm -f "$TEMP_CSV" "$SQL_FILE"
    exit 1
fi

# Clean up temporary files
rm -f "$TEMP_CSV" "$SQL_FILE"

# Get final stats
row_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $SCHEMA.works;")
row_count=$(echo "$row_count" | tr -d ' ')

table_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.works'));")
table_size=$(echo "$table_size" | tr -d ' ')

echo "Final row count: $row_count" | tee -a "$LOG_FILE"
echo "Final table size: $table_size" | tee -a "$LOG_FILE"
echo "Upload completed at $(date)" | tee -a "$LOG_FILE"
echo "=== Works table upload completed ===" | tee -a "$LOG_FILE"
