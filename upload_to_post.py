#!/usr/bin/env python3

import psycopg2
from psycopg2 import sql
from pathlib import Path

# Configuration
DSN = "dbname=openalex user=dbadmin password=openalex host=openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com port=5432 sslmode=require"
CSV_FILES = {
    "authors": "./csv-files/authors.csv",
    "institutions": "./csv-files/institutions.csv",
    "sources": "./csv-files/sources.csv"
}

def count_csv_rows(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        return sum(1 for line in f) - 1  # minus header

def upload_csv_to_postgres(table_name, file_path, conn):
    print(f"🚀 Uploading {file_path} → {table_name}...")
    with conn.cursor() as cur:
        with open(file_path, "r", encoding="utf-8") as f:
            cur.copy_expert(
                sql.SQL("COPY {} FROM STDIN WITH CSV HEADER").format(sql.Identifier(table_name)),
                f
            )
        conn.commit()
    print(f"✅ Finished uploading {table_name}")

def get_table_row_count(table_name, conn):
    with conn.cursor() as cur:
        cur.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(table_name)))
        return cur.fetchone()[0]

def main():
    conn = psycopg2.connect(DSN)

    for table, csv_file in CSV_FILES.items():
        if not Path(csv_file).exists():
            print(f"⚠️ File missing: {csv_file}")
            continue

        row_count = count_csv_rows(csv_file)
        print(f"\n📄 {csv_file} contains {row_count:,} rows")

        print(f"🧹 Truncating table {table}...")
        with conn.cursor() as cur:
            cur.execute(sql.SQL("TRUNCATE TABLE {}").format(sql.Identifier(table)))
            conn.commit()

        upload_csv_to_postgres(table, csv_file, conn)

        db_rows = get_table_row_count(table, conn)
        print(f"📥 Table {table} now has {db_rows:,} rows\n")

    conn.close()

if __name__ == "__main__":
    main()
