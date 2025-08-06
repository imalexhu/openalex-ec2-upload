#!/bin/bash
set -e

# Create output directory if it doesn't exist
OUTPUT_DIR="./csv-files"
mkdir -p "$OUTPUT_DIR"

# Python flatten script path
SCRIPT="./flatten-openalex-jsonl-py37.py"

echo "�� Flattening authors..."
python3 "$SCRIPT" \
  --input_dir "/home/ec2-user/openalex-snapshot/data/raw-authors" \
  --output_file "$OUTPUT_DIR/authors.csv" \
  --fields id,display_name,orcid,works_count,cited_by_count,updated_date
echo "✅ Done: authors.csv"

echo "🔁 Flattening institutions..."
python3 "$SCRIPT" \
  --input_dir "/home/ec2-user/openalex-snapshot/data/raw-institutions" \
  --output_file "$OUTPUT_DIR/institutions.csv" \
  --fields id,display_name,country_code,type,homepage_url,works_count,cited_by_count,updated_date
echo "✅ Done: institutions.csv"

echo "🔁 Flattening sources..."
python3 "$SCRIPT" \
  --input_dir "/home/ec2-user/openalex-snapshot/data/raw-sources" \
  --output_file "$OUTPUT_DIR/sources.csv" \
  --fields id,display_name,issn,issn_l,publisher,works_count,cited_by_count,is_oa,homepage_url,updated_date
echo "✅ Done: sources.csv"
