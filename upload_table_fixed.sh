#!/bin/bash
# Script to upload a single table using the fixed approach

# Input validation
if [ $# -ne 1 ]; then
    echo "Usage: $0 <table_number>"
    echo "1: works"
    echo "2: works_ids"
    echo "3: works_authorships"
    echo "4: works_concepts"
    echo "5: works_referenced_works"
    echo "6: works_related_works"
    echo "7: works_open_access"
    echo "8: works_counts_by_year"
    exit 1
fi

# Map table number to name and file
case $1 in
    1) 
        TABLE="works"
        FILE="csv-files/works.csv"
        ;;
    2) 
        TABLE="works_ids"
        FILE="csv-files/works_ids.csv"
        ;;
    3) 
        TABLE="works_authorships"
        FILE="csv-files/works_authorships.csv"
        ;;
    4) 
        TABLE="works_concepts"
        FILE="csv-files/works_concepts.csv"
        ;;
    5) 
        TABLE="works_referenced_works"
        FILE="csv-files/works_referenced_works.csv"
        ;;
    6) 
        TABLE="works_related_works"
        FILE="csv-files/works_related_works.csv"
        ;;
    7) 
        TABLE="works_open_access"
        FILE="csv-files/works_open_access.csv"
        ;;
    8) 
        TABLE="works_counts_by_year"
        FILE="csv-files/works_counts_by_year.csv"
        ;;
    *) 
        echo "Invalid table number"
        exit 1
        ;;
esac

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File not found at $FILE"
    exit 1
fi

# Check for an existing screen session
SCREEN_NAME="upload_$TABLE"
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "Screen session '$SCREEN_NAME' already exists."
    echo "Do you want to terminate it and start a new one? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        screen -S "$SCREEN_NAME" -X quit
        sleep 1
    else
        echo "Exiting without starting a new upload."
        exit 0
    fi
fi

# Start upload in a new screen session
echo "Starting upload for table $TABLE..."
screen -dmS "$SCREEN_NAME" bash -c "./fix_upload.sh \"$FILE\" \"$TABLE\" 2>&1"
echo "Upload started in screen session: $SCREEN_NAME"
echo "To view progress: screen -r $SCREEN_NAME"
echo "To detach from session after viewing: Ctrl+A, D"
echo "To check logs: tail -f logs/${TABLE}_upload.log"
