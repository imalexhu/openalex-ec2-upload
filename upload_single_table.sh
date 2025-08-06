#!/bin/bash
# Simple script to upload a single table

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

# Create logs directory
mkdir -p logs

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

# Start the upload in a screen session
SCREEN_NAME="upload_$TABLE"

# Check if a screen session already exists with this name
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "A screen session named $SCREEN_NAME already exists."
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

# Start the upload in a screen session
echo "Starting upload for $TABLE..."
screen -dmS "$SCREEN_NAME" bash -c "./upload_csv.sh \"$FILE\" \"$TABLE\" 2>&1 | tee logs/${TABLE}_screen.log"

echo "Upload started in screen session: $SCREEN_NAME"
echo "To view this session: screen -r $SCREEN_NAME"
echo "To detach from session after viewing: Ctrl+A, D"
echo "To monitor progress: tail -f logs/${TABLE}_screen.log"
