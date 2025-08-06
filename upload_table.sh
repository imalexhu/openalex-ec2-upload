#!/bin/bash
# upload_table.sh - Script to upload a specific CSV file to a database table (FIXED VERSION)
# Usage: ./upload_table.sh <csv_file> <table_name>

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <csv_file> <table_name>"
    echo "Example: $0 csv-files/works_ids.csv works_ids"
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
LOGS_DIR="logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Log file for this upload
LOG_FILE="$LOGS_DIR/${TABLE_NAME}_upload.log"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found at $CSV_FILE"
    exit 1
fi

# Check if the table exists
table_exists=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "
SELECT EXISTS(
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_schema = '$SCHEMA' AND table_name = '$TABLE_NAME'
);
")

if [[ ! $table_exists =~ t ]]; then
    echo "Error: Table '$SCHEMA.$TABLE_NAME' does not exist in the database."
    exit 1
fi

# Get file size for progress calculation
FILE_SIZE=$(stat -c%s "$CSV_FILE")
echo "File size: $FILE_SIZE bytes"

# Count total lines in the CSV file
echo "Counting lines in CSV file (this might take a while for large files)..."
TOTAL_LINES=$(wc -l < "$CSV_FILE")
echo "Total lines in CSV: $TOTAL_LINES"

# Choose upload method based on file size
if [ $FILE_SIZE -lt 5000000000 ]; then  # Less than 5GB
    echo "Using direct upload method for smaller file..."
    
    echo "Starting data upload for $TABLE_NAME from $CSV_FILE..."
    echo "Upload started at: $(date)" | tee -a "$LOG_FILE"
    
    # Use psql \copy command directly without trying to pipe through it
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\copy $SCHEMA.$TABLE_NAME FROM '$CSV_FILE' WITH (FORMAT csv, HEADER);"
    
else
    # For larger files, use the chunking approach
    echo "Using chunked upload method for larger file..."
    
    # Create a temporary directory for chunks
    CHUNK_DIR="/tmp/${TABLE_NAME}_chunks"
    mkdir -p "$CHUNK_DIR"
    
    # Get the header line
    HEAD_LINE=$(head -n 1 "$CSV_FILE")
    
    # Calculate chunk size (approximately 1 million lines)
    CHUNK_SIZE=1000000
    CHUNK_COUNT=$(( (TOTAL_LINES - 1 + CHUNK_SIZE - 1) / CHUNK_SIZE ))
    echo "Will process data in $CHUNK_COUNT chunks" | tee -a "$LOG_FILE"
    
    # Process chunks
    for ((i=1; i<=$CHUNK_COUNT; i++)); do
        echo "Processing chunk $i of $CHUNK_COUNT..." | tee -a "$LOG_FILE"
        
        # Calculate line range for this chunk
        START_LINE=$(( (i-1) * CHUNK_SIZE + 2 )) # +2 to skip header and start from data
        END_LINE=$(( START_LINE + CHUNK_SIZE - 1 ))
        if [ $END_LINE -gt $TOTAL_LINES ]; then
            END_LINE=$TOTAL_LINES
        fi
        
        CHUNK_FILE="$CHUNK_DIR/chunk_${i}.csv"
        
        echo "Creating chunk file from lines $START_LINE to $END_LINE..." | tee -a "$LOG_FILE"
        # Create chunk file with header
        echo "$HEAD_LINE" > "$CHUNK_FILE"
        sed -n "${START_LINE},${END_LINE}p" "$CSV_FILE" >> "$CHUNK_FILE"
        
        echo "Loading chunk $i into database..." | tee -a "$LOG_FILE"
        start_time=$(date +%s)
        
        # Use psql \copy command directly without trying to pipe through it
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\copy $SCHEMA.$TABLE_NAME FROM '$CHUNK_FILE' WITH (FORMAT csv, HEADER);"
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Calculate progress
        PROGRESS=$(( 100 * i / CHUNK_COUNT ))
        echo "Chunk $i completed in $duration seconds" | tee -a "$LOG_FILE"
        echo "Progress: $PROGRESS% complete ($i of $CHUNK_COUNT chunks)" | tee -a "$LOG_FILE"
        
        # Remove chunk file to save space
        rm "$CHUNK_FILE"
        
        # Count rows to verify
        row_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM $SCHEMA.$TABLE_NAME;")
        row_count=$(echo $row_count | tr -d ' ')
        echo "Current row count in $TABLE_NAME: $row_count" | tee -a "$LOG_FILE"
    done
    
    # Clean up chunk directory
    rmdir "$CHUNK_DIR"
fi

# Count rows to verify
row_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM $SCHEMA.$TABLE_NAME;")
row_count=$(echo $row_count | tr -d ' ')

# Verify table size
table_size=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -t -c "
    SELECT pg_size_pretty(pg_relation_size('$SCHEMA.$TABLE_NAME'));
")
table_size=$(echo $table_size | tr -d ' ')

echo "Upload completed at: $(date)" | tee -a "$LOG_FILE"
echo "Final row count in $TABLE_NAME: $row_count" | tee -a "$LOG_FILE"
echo "Table size: $table_size" | tee -a "$LOG_FILE"

echo "=== Upload for $TABLE_NAME completed successfully ==="
echo "Check $LOG_FILE for detailed log"
