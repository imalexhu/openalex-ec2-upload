#!/bin/bash
echo "Monitoring PostgreSQL tables..."
while true; do
    clear
    echo "Current time: $(date)"
    echo ""
    echo "Current table sizes:"
    echo "------------------------------------------------"
    PGPASSWORD=openalex psql -h openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com -U dbadmin -d openalex -c "SELECT table_name, pg_size_pretty(pg_total_relation_size('openalex.' || table_name)) as size, (SELECT count(*) FROM openalex.\"${table_name}\") as row_count FROM information_schema.tables WHERE table_schema = 'openalex' ORDER BY pg_total_relation_size('openalex.' || table_name) DESC;"
    echo ""
    echo "Active screens:"
    screen -ls
    echo ""
    echo "Press Ctrl+C to exit monitoring"
    sleep 60
done
