#!/usr/bin/env python3
import os
import gzip
import json
import argparse
import csv
from pathlib import Path
from tqdm import tqdm  # Add this for progress bar

def read_jsonl_gz(file_path):
    with gzip.open(file_path, 'rt', encoding='utf-8') as f:
        for line in f:
            yield json.loads(line)

def extract_fields(obj, fields):
    return [obj.get(field, '') for field in fields]

def main():
    parser = argparse.ArgumentParser(description="Flatten OpenAlex JSONL files into CSV")
    parser.add_argument('--input_dir', required=True, help="Input directory with .jsonl.gz files")
    parser.add_argument('--output_file', required=True, help="Output CSV file path")
    parser.add_argument('--fields', required=True, help="Comma-separated field names to extract")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_path = Path(args.output_file)
    fields = args.fields.split(',')

    all_input_files = list(input_dir.rglob("*.gz"))
    if not all_input_files:
        print(f"❌ No .gz files found in {input_dir}")
        return

    print(f"🔍 Found {len(all_input_files)} files in {input_dir}")
    total_rows = 0

    with open(output_path, 'w', newline='', encoding='utf-8') as out_csv:
        writer = csv.writer(out_csv)
        writer.writerow(fields)  # header

        for i, file_path in enumerate(tqdm(all_input_files, desc="Processing files", unit="file")):
            row_count = 0
            try:
                for obj in read_jsonl_gz(file_path):
                    writer.writerow(extract_fields(obj, fields))
                    total_rows += 1
                    row_count += 1
            except Exception as e:
                print(f"⚠️ Error reading {file_path}: {e}")
                continue
            tqdm.write(f"✅ {file_path.name}: {row_count} rows")

    print(f"\n�� Done! Wrote {total_rows} rows to {output_path}")

if __name__ == '__main__':
    main()
