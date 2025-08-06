#!/bin/bash
# Script to start uploads for all tables in separate screen sessions

# Create logs directory
mkdir -p logs

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

echo "=== Starting Uploads for All Tables ==="

# Define tables and their CSV files
declare -A TABLE_MAP
TABLE_MAP["works"]="csv-files/works.csv"
TABLE_MAP["works_ids"]="csv-files/works_ids.csv"
TABLE_MAP["works_authorships"]="csv-files/works_authorships.csv"
TABLE_MAP["works_concepts"]="csv-files/works_concepts.csv"
TABLE_MAP["works_referenced_works"]="csv-files/works_referenced_works.csv"
TABLE_MAP["works_related_works"]="csv-files/works_related_works.csv"
TABLE_MAP["works_open_access"]="csv-files/works_open_access.csv"
TABLE_MAP["works_counts_by_year"]="csv-files/works_counts_by_year.csv"

# Check for existing screen sessions and stop them
echo "Checking for existing upload sessions..."
for table in "${!TABLE_MAP[@]}"; do
    screen_name="upload_$table"
    if screen -list | grep -q "$screen_name"; then
        echo "Stopping existing session: $screen_name"
        screen -S "$screen_name" -X quit
        sleep 1
    fi
done

# Start uploads for all tables
for table in "${!TABLE_MAP[@]}"; do
    csv_file="${TABLE_MAP[$table]}"
    
    # Check if file exists
    if [ ! -f "$csv_file" ]; then
        echo "⚠️ Warning: CSV file not found: $csv_file - Skipping $table"
        continue
    fi
    
    # Create a temporary SQL script file for this table
    sql_file="/tmp/upload_${table}.sql"
    
    cat > "$sql_file" << EOL
-- Temporary SQL script to load data for $table
SET work_mem = '256MB';
SET synchronous_commit TO OFF;
\\copy $SCHEMA.$table FROM '$csv_file' CSV HEADER;
EOL
    
    # Start upload in a new screen session
    screen_name="upload_$table"
    echo "Starting upload for $table (from $csv_file)..."
    
    # Command to execute in the screen session
    cmd="PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f $sql_file 2>&1 | tee logs/${table}_upload.log; rm $sql_file"
    
    # Create the screen session
    screen -dmS "$screen_name" bash -c "$cmd"
    echo "✅ Started upload in screen session: $screen_name"
    
    # Brief pause to avoid overwhelming the database
    sleep 2
done

echo
echo "=== All uploads started ==="
echo "Use './monitor_all_uploads.sh' to monitor progress"
echo "Active screen sessions:"
screen -ls | grep "upload_" || echo "No active upload sessions"
