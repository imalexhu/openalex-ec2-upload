#!/bin/bash

# Database connection parameters
DB_HOST="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_NAME="openalex"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
SCHEMA="openalex"

# Define table names and corresponding CSV files
TABLES=(
    "works:csv-files/works.csv"
    "works_ids:csv-files/works_ids.csv"
    "works_authorships:csv-files/works_authorships.csv"
    "works_concepts:csv-files/works_concepts.csv"
    "works_referenced_works:csv-files/works_referenced_works.csv"
    "works_related_works:csv-files/works_related_works.csv"
    "works_open_access:csv-files/works_open_access.csv"
    "works_counts_by_year:csv-files/works_counts_by_year.csv"
)

for table_info in "${TABLES[@]}"; do
    # Split into table name and CSV file
    table_name=$(echo $table_info | cut -d':' -f1)
    csv_file=$(echo $table_info | cut -d':' -f2)
    
    echo "=== Checking $table_name ==="
    
    # Get CSV headers
    if [ -f "$csv_file" ]; then
        echo "CSV headers from $csv_file:"
        head -1 "$csv_file"
        echo ""
    else
        echo "WARNING: CSV file $csv_file not found!"
        continue
    fi
    
    # Get table schema
    echo "Database schema for $SCHEMA.$table_name:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
    SELECT 
        column_name, 
        data_type
    FROM 
        information_schema.columns 
    WHERE 
        table_schema = '$SCHEMA' AND 
        table_name = '$table_name'
    ORDER BY 
        ordinal_position;
    "
    echo ""
    
    # Check data sample
    echo "First 5 lines of CSV data:"
    head -6 "$csv_file" | tail -5
    echo ""
    echo "==================================="
    echo ""
done
