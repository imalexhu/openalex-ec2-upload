#!/usr/bin/env python3

import psycopg2
from psycopg2 import sql

DSN = "dbname=openalex user=dbadmin password=openalex host=openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com port=5432 sslmode=require"

TABLES = {
    "authors": """
        CREATE TABLE IF NOT EXISTS authors (
            id TEXT PRIMARY KEY,
            display_name TEXT,
            orcid TEXT,
            works_count INTEGER,
            cited_by_count INTEGER,
            updated_date DATE
        );
    """,
    "institutions": """
        CREATE TABLE IF NOT EXISTS institutions (
            id TEXT PRIMARY KEY,
            display_name TEXT,
            country_code TEXT,
            type TEXT,
            homepage_url TEXT,
            works_count INTEGER,
            cited_by_count INTEGER,
            updated_date DATE
        );
    """,
    "sources": """
        CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            display_name TEXT,
            issn TEXT,
            issn_l TEXT,
            publisher TEXT,
            works_count INTEGER,
            cited_by_count INTEGER,
            is_oa BOOLEAN,
            homepage_url TEXT,
            updated_date DATE
        );
    """
}

def main():
    conn = psycopg2.connect(DSN)
    with conn.cursor() as cur:
        for name, ddl in TABLES.items():
            print(f"🔧 Creating table `{name}` if not exists...")
            cur.execute(ddl)
    conn.commit()
    conn.close()
    print("✅ All tables created.")

if __name__ == "__main__":
    main()
