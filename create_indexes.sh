#!/bin/bash

DB_ENDPOINT="openalex-works-db.cotaglzvldnm.us-west-2.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="openalex"
DB_NAME="openalex"

echo "===== CREATING INDEXES ====="
echo "Started at: $(date)"

PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c "
CREATE INDEX works_id_idx ON openalex.works (id);
CREATE INDEX works_doi_idx ON openalex.works (doi);
CREATE INDEX works_publication_year_idx ON openalex.works (publication_year);
CREATE INDEX works_type_idx ON openalex.works (type);
CREATE INDEX works_cited_by_count_idx ON openalex.works (cited_by_count);
CREATE INDEX works_authorships_work_id_idx ON openalex.works_authorships (work_id);
CREATE INDEX works_authorships_author_id_idx ON openalex.works_authorships (author_id);
CREATE INDEX works_concepts_work_id_idx ON openalex.works_concepts (work_id);
CREATE INDEX works_concepts_concept_id_idx ON openalex.works_concepts (concept_id);
CREATE INDEX works_referenced_works_work_id_idx ON openalex.works_referenced_works (work_id);
CREATE INDEX works_related_works_work_id_idx ON openalex.works_related_works (work_id);
CREATE INDEX works_open_access_is_oa_idx ON openalex.works_open_access (is_oa);
CREATE INDEX works_counts_by_year_work_id_idx ON openalex.works_counts_by_year (work_id);
CREATE INDEX works_ids_work_id_idx ON openalex.works_ids (work_id);
CREATE INDEX works_ids_doi_idx ON openalex.works_ids (doi);
"

echo "===== INDEXES CREATED ====="
echo "Finished at: $(date)"
