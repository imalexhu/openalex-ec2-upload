#!/bin/bash
# start_uploads.sh - Simplified script to start table uploads in separate screen sessions

# Create logs directory if it doesn't exist
LOGS_DIR="logs"
mkdir -p "$LOGS_DIR"

echo "=== Starting Table Uploads in Separate Screen Sessions ==="

# Define table configurations as simple arrays
TABLE_FILES=("csv-files/works.csv" "csv-files/works_ids.csv" "csv-files/works_authorships.csv" "csv-files/works_concepts.csv" "csv-files/works_referenced_works.csv" "csv-files/works_related_works.csv" "csv-files/works_open_access.csv" "csv-files/works_counts_by_year.csv")

TABLE_NAMES=("works" "works_ids" "works_authorships" "works_concepts" "works_referenced_works" "works_related_works" "works_open_access" "works_counts_by_year")

TABLE_DESC=("Main works table" "Works identifiers" "Works authorships" "Works concepts" "Works referenced works" "Works related works" "Works open access" "Works citation counts by year")

# Check that upload_table.sh exists
if [ ! -f "upload_table.sh" ]; then
    echo "Error: upload_table.sh script not found in current directory"
    exit 1
fi

# Make sure it's executable
chmod +x upload_table.sh

# Check for existing screen sessions
echo "Checking for existing screen sessions..."
screen -ls

# Display options
echo "Which tables would you like to upload?"
echo "Enter table numbers (e.g., '1' for works, '2 5' for works_ids and works_referenced_works)"
echo "Or enter 'all' to upload all tables"
echo ""

# List all tables
for i in "${!TABLE_NAMES[@]}"; do
    if [ -f "${TABLE_FILES[$i]}" ]; then
        file_status="(File exists)"
    else
        file_status="(File NOT found)"
    fi
    
    echo "$((i+1))) ${TABLE_NAMES[$i]} - ${TABLE_DESC[$i]} $file_status"
done

# Get user selection
echo ""
read -p "Tables to upload: " table_selection

# Start uploads based on selection
if [ "$table_selection" = "all" ]; then
    # Upload all tables
    for i in "${!TABLE_NAMES[@]}"; do
        csv_file="${TABLE_FILES[$i]}"
        table_name="${TABLE_NAMES[$i]}"
        description="${TABLE_DESC[$i]}"
        
        if [ ! -f "$csv_file" ]; then
            echo "⚠️ CSV file not found: $csv_file - Skipping"
            continue
        fi
        
        screen_name="upload_${table_name}"
        echo "Starting upload for $table_name ($description)..."
        screen -dmS "$screen_name" bash -c "./upload_table.sh \"$csv_file\" \"$table_name\" 2>&1 | tee $LOGS_DIR/${table_name}_screen.log"
        echo "✅ Started upload in screen session: $screen_name"
        echo "  - To attach: screen -r $screen_name"
        echo "  - To detach: Ctrl+A, D"
        sleep 2
    done
else
    # Upload selected tables
    for num in $table_selection; do
        i=$((num-1))
        
        if [ $i -ge 0 ] && [ $i -lt ${#TABLE_NAMES[@]} ]; then
            csv_file="${TABLE_FILES[$i]}"
            table_name="${TABLE_NAMES[$i]}"
            description="${TABLE_DESC[$i]}"
            
            if [ ! -f "$csv_file" ]; then
                echo "⚠️ CSV file not found: $csv_file - Skipping"
                continue
            fi
            
            screen_name="upload_${table_name}"
            echo "Starting upload for $table_name ($description)..."
            screen -dmS "$screen_name" bash -c "./upload_table.sh \"$csv_file\" \"$table_name\" 2>&1 | tee $LOGS_DIR/${table_name}_screen.log"
            echo "✅ Started upload in screen session: $screen_name"
            echo "  - To attach: screen -r $screen_name"
            echo "  - To detach: Ctrl+A, D"
            sleep 2
        else
            echo "Invalid selection: $num"
        fi
    done
fi

echo "=== All selected uploads started ==="
echo "Active screen sessions:"
screen -ls | grep "upload_" || echo "No active upload sessions"
echo ""
echo "To monitor all uploads, use: ./monitor_uploads.sh"
