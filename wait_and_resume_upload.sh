#!/bin/bash

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"
WORKS_CSV="csv-files/works.csv"
LOG_FILE="logs/wait_and_upload.log"

mkdir -p logs

echo "=== Starting automated wait and resume upload script ===" | tee -a "$LOG_FILE"
echo "Start time: $(date)" | tee -a "$LOG_FILE"

# Function to check RDS status
check_rds_status() {
    status=$(aws rds describe-db-instances --db-instance-identifier openalex-works-db --query "DBInstances[0].DBInstanceStatus" --output text)
    echo "$status"
}

# Wait for RDS to become available
echo "Waiting for RDS instance to become available..." | tee -a "$LOG_FILE"
current_status=$(check_rds_status)
echo "Current RDS status: $current_status" | tee -a "$LOG_FILE"

while [ "$current_status" != "available" ]; do
    echo "$(date): RDS status is $current_status. Waiting 5 minutes before checking again..." | tee -a "$LOG_FILE"
    sleep 300  # Wait 5 minutes
    current_status=$(check_rds_status)
    echo "$(date): RDS status is now $current_status" | tee -a "$LOG_FILE"
done

echo "$(date): RDS is now available! Proceeding with works table upload." | tee -a "$LOG_FILE"

# Check if works table has any existing rows
existing_rows=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $SCHEMA.works;")
existing_rows=$(echo "$existing_rows" | tr -d ' ')
echo "Works table has $existing_rows existing rows" | tee -a "$LOG_FILE"

# Total lines in CSV file
TOTAL_LINES=$(wc -l < "$WORKS_CSV")
echo "Total lines in CSV file: $TOTAL_LINES" | tee -a "$LOG_FILE"

if [ "$existing_rows" -gt "0" ]; then
    echo "Resuming upload from row $existing_rows (skipping already loaded data)" | tee -a "$LOG_FILE"
    
    # The upload failed at line 107253970 previously, so we'll use that as our resume point
    # If it failed at a different line, you'd need to adjust this value
    RESUME_LINE=107253971
    
    echo "Using resume line: $RESUME_LINE based on previous error" | tee -a "$LOG_FILE"
    
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
    
    # Prepare SQL for resuming upload
    SQL_FILE="/tmp/resume_works_upload.sql"
    cat > "$SQL_FILE" << EOL
-- Optimize PostgreSQL settings for bulk loading
SET work_mem = '1GB';
SET maintenance_work_mem = '2GB';
SET synchronous_commit TO OFF;
SET temp_buffers = '512MB';
-- Load the remaining data
\\copy $SCHEMA.works FROM '$TEMP_CSV' CSV HEADER;
EOL

else
    echo "Works table is empty. Starting fresh upload." | tee -a "$LOG_FILE"
    
    # Prepare SQL for full upload
    SQL_FILE="/tmp/upload_works.sql"
    cat > "$SQL_FILE" << EOL
-- Optimize PostgreSQL settings for bulk loading
SET work_mem = '1GB';
SET maintenance_work_mem = '2GB';
SET synchronous_commit TO OFF;
SET temp_buffers = '512MB';
-- Load the data
\\copy $SCHEMA.works FROM '$WORKS_CSV' CSV HEADER;
EOL
fi

# Start the upload
echo "Starting works table upload at $(date)..." | tee -a "$LOG_FILE"
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
    # Don't exit here, try to proceed with other operations like index creation
fi

# Get final stats
row_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $SCHEMA.works;")
row_count=$(echo "$row_count" | tr -d ' ')

table_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_relation_size('$SCHEMA.works'));")
table_size=$(echo "$table_size" | tr -d ' ')

echo "Final row count: $row_count" | tee -a "$LOG_FILE"
echo "Final table size: $table_size" | tee -a "$LOG_FILE"
echo "Upload completed at $(date)" | tee -a "$LOG_FILE"
echo "=== Works table upload completed ===" | tee -a "$LOG_FILE"

# After successful upload, create indexes if they don't exist
echo "Creating indexes on works table if they don't exist..." | tee -a "$LOG_FILE"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE INDEX IF NOT EXISTS idx_works_id ON $SCHEMA.works(id);
CREATE INDEX IF NOT EXISTS idx_works_publication_year ON $SCHEMA.works(publication_year);
CREATE INDEX IF NOT EXISTS idx_works_type ON $SCHEMA.works(type);
" 2>&1 | tee -a "$LOG_FILE"

echo "Running ANALYZE on works table..." | tee -a "$LOG_FILE"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "ANALYZE $SCHEMA.works;" 2>&1 | tee -a "$LOG_FILE"

echo "All operations completed successfully at $(date)" | tee -a "$LOG_FILE"

# Clean up temporary files
if [ -f "$TEMP_CSV" ]; then
    rm -f "$TEMP_CSV"
fi
rm -f "$SQL_FILE"
