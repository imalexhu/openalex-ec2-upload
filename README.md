# OpenAlex EC2 Upload Pipeline

This repository contains a collection of shell scripts, SQL schemas, and Python utilities designed to ingest the [OpenAlex](https://openalex.org/) dataset into a PostgreSQL database hosted on an AWS EC2 instance. The system is optimized for batch ingestion, indexing, fault recovery, and performance monitoring of large-scale academic data.

---

## 📦 Repository Purpose

The goal of this repository is to provide a modular, scriptable pipeline to:

- Flatten raw OpenAlex JSONL data into relational formats
- Upload large datasets into PostgreSQL in parallel or staged modes
- Manage database schema creation, indexing, and maintenance
- Monitor ingestion progress, detect failures, and support resume-on-crash functionality

---

## 🛠️ Technologies Used

- **PostgreSQL** — primary data store for OpenAlex content
- **Bash** — orchestration, control flow, and monitoring scripts
- **Python** — JSONL flattening and schema transformation utilities
- **SQL** — DDL and DML scripts for schema, indexes, and constraints
- **AWS EC2** — compute environment for scalable ingestion

---

## 📁 Directory and Script Structure

| File/Dir                      | Purpose |
|------------------------------|---------|
| `create_tables.py`           | Creates necessary PostgreSQL tables |
| `flatten-openalex-*.py`      | Flattens OpenAlex JSONL files into CSV-ready tables |
| `load_works*.sql`            | SQL scripts to bulk load each OpenAlex table |
| `upload_*.sh`                | Shell scripts to run full upload pipelines |
| `monitor_*.sh`               | Scripts to monitor and resume failed uploads |
| `fix_*.sh`                   | Helpers for schema updates or failed state recovery |
| `*.sql`                      | Schema creation, indexing, and performance tuning |
| `*.sh`                       | Full ETL orchestration, logging, and control logic |

> ⚠️ Large `.csv` and `.db` files are git-ignored to keep the repo lightweight. You must mount or fetch OpenAlex data separately before ingestion.

---

## 🚀 Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/imalexhu/openalex-ec2-upload.git
cd openalex-ec2-upload
