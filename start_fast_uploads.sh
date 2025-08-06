#!/bin/bash
# Start uploads with the faster direct method

# Create logs directory
mkdir -p logs

# Define table configurations
TABLES=(
    "works:csv-files/works.csv:Main works table"
    "works_ids:csv-files/works_ids.csv:Works identifiers"
    "works_authorships:csv-files/works_authorships.csv:Works authorships"
    "works_concepts:csv-files/works_concepts.csv:Works concepts"
    "works_referenced_works:csv-files/works_referenced_works.csv:Works referenced works"
    "works_related_works:csv-files/works_related_works.csv:Works related works"
    "works_open_access:csv-files/works_open_access.csv:Works open access"
    "works_counts_by_year:csv-files/works_counts_by_year.csv:Works citation counts by year"
)

echo "Which tables would you like to upload? (Enter table numbers separated by spaces, or 'all')"
for i in "${!TABLES[@]}"; do
    table_config="${TABLES[$i]}"
    table_name=$(echo $table_config | cut -d':' -f1)
    csv_file=$(echo $table_config | cut -d':' -f2)
    description=$(echo $table_config | cut -d':' -f3)
    
    if [ -f "$csv_file" ]; then
        status="(File exists)"
    else
        status="(File missing)"
    fi
    
    echo "$((i+1))) $table_name - $description $status"
done

read -p "Tables to upload: " selection

if [ "$selection" = "all" ]; then
    selected_indices=$(seq 0 $((${#TABLES[@]}-1)))
else
    selected_indices=()
    for num in $selection; do
        selected_indices+=($((num-1)))
    done
fi

for index in $selected_indices; do
    if [ $index -ge 0 ] && [ $index -lt ${#TABLES[@]} ]; then
        table_config="${TABLES[$index]}"
        table_name=$(echo $table_config | cut -d':' -f1)
        csv_file=$(echo $table_config | cut -d':' -f2)
        description=$(echo $table_config | cut -d':' -f3)
        
        if [ ! -f "$csv_file" ]; then
            echo "⚠️ Warning: CSV file not found: $csv_file - Skipping"
            continue
        fi
        
        screen_name="upload_${table_name}"
        echo "Starting upload for $table_name ($description)..."
        screen -dmS "$screen_name" bash -c "./upload_fast.sh \"$csv_file\" \"$table_name\" 2>&1 | tee logs/${table_name}_screen.log"
        echo "✅ Started upload in screen session: $screen_name"
    fi
done

echo "=== Uploads started ==="
echo "Use 'screen -ls' to see active sessions"
echo "Use './monitor_uploads.sh' to monitor progress"
