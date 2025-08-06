#!/bin/bash
# Simple script to start uploads for selected tables

# Create logs directory
mkdir -p logs

echo "=== Starting Fast Uploads ==="

# List table options
echo "Which table would you like to upload?"
echo "1) works - Main works table"
echo "2) works_ids - Works identifiers"
echo "3) works_authorships - Works authorships"
echo "4) works_concepts - Works concepts"
echo "5) works_referenced_works - Works referenced works"
echo "6) works_related_works - Works related works"
echo "7) works_open_access - Works open access"
echo "8) works_counts_by_year - Works citation counts by year"
echo "9) ALL TABLES"

read -p "Enter number (1-9): " choice

case $choice in
    1)
        csv_file="csv-files/works.csv"
        table_name="works"
        ;;
    2)
        csv_file="csv-files/works_ids.csv"
        table_name="works_ids"
        ;;
    3)
        csv_file="csv-files/works_authorships.csv"
        table_name="works_authorships"
        ;;
    4)
        csv_file="csv-files/works_concepts.csv"
        table_name="works_concepts"
        ;;
    5)
        csv_file="csv-files/works_referenced_works.csv"
        table_name="works_referenced_works"
        ;;
    6)
        csv_file="csv-files/works_related_works.csv"
        table_name="works_related_works"
        ;;
    7)
        csv_file="csv-files/works_open_access.csv"
        table_name="works_open_access"
        ;;
    8)
        csv_file="csv-files/works_counts_by_year.csv"
        table_name="works_counts_by_year"
        ;;
    9)
        echo "Starting uploads for ALL tables..."
        
        # Start each table upload in a separate screen session
        for t in works works_ids works_authorships works_concepts works_referenced_works works_related_works works_open_access works_counts_by_year; do
            f="csv-files/$t.csv"
            if [ ! -f "$f" ]; then
                echo "Warning: File not found - $f - Skipping"
                continue
            fi
            
            screen_name="upload_$t"
            screen -dmS "$screen_name" bash -c "./upload_fast.sh \"$f\" \"$t\" 2>&1 | tee logs/${t}_screen.log"
            echo "Started upload for $t in screen session: $screen_name"
        done
        
        echo "All uploads started. Use 'screen -ls' to see sessions."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# For single table upload
if [ ! -f "$csv_file" ]; then
    echo "Error: File not found - $csv_file"
    exit 1
fi

# Start the upload
screen_name="upload_$table_name"
screen -dmS "$screen_name" bash -c "./upload_fast.sh \"$csv_file\" \"$table_name\" 2>&1 | tee logs/${table_name}_screen.log"
echo "Started upload for $table_name in screen session: $screen_name"
echo "To attach to this session: screen -r $screen_name"
echo "To detach after attaching: Ctrl+A, D"
echo "To view progress: tail -f logs/${table_name}_screen.log"

echo "=== Upload started ==="
