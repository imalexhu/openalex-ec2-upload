#!/usr/bin/env python3
import os
import gzip
import json
import argparse
import csv
from pathlib import Path

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

    count = 0
    with open(output_path, 'w', newline='', encoding='utf-8') as out_csv:
        writer = csv.writer(out_csv)
        writer.writerow(fields)  # header

        for file_path in all_input_files:
            for obj in read_jsonl_gz(file_path):
                writer.writerow(extract_fields(obj, fields))
                count += 1

    print(f"✅ Wrote {count} rows to {output_path}")

if __name__ == '__main__':
    main()
