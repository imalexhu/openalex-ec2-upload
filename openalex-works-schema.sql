CREATE SCHEMA openalex;

CREATE TABLE openalex.works (
    id text NOT NULL,
    doi text,
    title text,
    display_name text,
    publication_year integer,
    publication_date date,
    type text,
    type_crossref text,
    cited_by_count integer,
    is_retracted boolean,
    is_paratext boolean,
    cited_by_api_url text,
    abstract_inverted_index json,
    language text,
    has_fulltext boolean,
    fulltext_origin text,
    volume text,
    issue text,
    first_page text,
    last_page text,
    updated_date timestamp without time zone
);

CREATE TABLE openalex.works_ids (
    work_id text,
    openalex text,
    doi text,
    mag text,
    pmid text,
    pmcid text,
    arxiv text,
    isbn13 text,
    isbn10 text,
    jstor text
);

CREATE TABLE openalex.works_primary_location (
    work_id text,
    source_id text,
    source_display_name text,
    source_type text,
    source_publisher text,
    source_country_code text,
    source_is_in_doaj boolean,
    is_oa boolean,
    landing_page_url text,
    pdf_url text,
    license text,
    version text
);

CREATE TABLE openalex.works_best_oa_location (
    work_id text,
    source_id text,
    source_display_name text,
    source_type text,
    source_publisher text,
    source_country_code text,
    source_is_in_doaj boolean,
    is_oa boolean,
    landing_page_url text,
    pdf_url text,
    license text,
    version text
);

CREATE TABLE openalex.works_locations (
    work_id text,
    source_id text,
    source_display_name text,
    source_type text,
    source_publisher text,
    source_country_code text,
    source_is_in_doaj boolean,
    is_oa boolean,
    landing_page_url text,
    pdf_url text,
    license text,
    version text
);

CREATE TABLE openalex.works_open_access (
    work_id text,
    is_oa boolean,
    oa_status text,
    oa_url text,
    any_repository_has_fulltext boolean
);

CREATE TABLE openalex.works_authorships (
    work_id text,
    author_position text,
    author_id text,
    author_display_name text,
    author_orcid text,
    institution_id text,
    institution_display_name text,
    institution_ror text,
    institution_type text,
    institution_country_code text,
    raw_author_name text,
    raw_affiliation_string text,
    raw_affiliation_names text[]
);

CREATE TABLE openalex.works_concepts (
    work_id text,
    concept_id text,
    concept_display_name text,
    concept_wikidata text,
    concept_level integer,
    score real
);

CREATE TABLE openalex.works_topics (
    work_id text,
    topic_id text,
    topic_display_name text,
    topic_subfield_id text,
    topic_subfield_display_name text,
    topic_field_id text,
    topic_field_display_name text,
    topic_domain_id text,
    topic_domain_display_name text,
    score real
);

CREATE TABLE openalex.works_mesh (
    work_id text,
    descriptor_ui text,
    descriptor_name text,
    qualifier_ui text,
    qualifier_name text,
    is_major_topic boolean
);

CREATE TABLE openalex.works_keywords (
    work_id text,
    keyword_id text,
    display_name text,
    score real
);

CREATE TABLE openalex.works_referenced_works (
    work_id text,
    referenced_work_id text
);

CREATE TABLE openalex.works_related_works (
    work_id text,
    related_work_id text
);

CREATE TABLE openalex.works_grants (
    work_id text,
    funder_id text,
    funder_display_name text,
    award_id text
);

CREATE TABLE openalex.works_counts_by_year (
    work_id text,
    year integer,
    cited_by_count integer
);

CREATE TABLE openalex.works_sustainable_development_goals (
    work_id text,
    sdg_id text,
    sdg_display_name text,
    score real
);

CREATE TABLE openalex.works_field_of_study (
    work_id text,
    field_id text,
    field_display_name text
);

CREATE TABLE openalex.works_alternate_host_venues (
    work_id text,
    venue_id text,
    venue_name text,
    url text,
    is_oa boolean,
    version text,
    license text
);

-- Create indexes for efficient querying
CREATE INDEX works_id_idx ON openalex.works (id);
CREATE INDEX works_doi_idx ON openalex.works (doi);
CREATE INDEX works_publication_year_idx ON openalex.works (publication_year);
CREATE INDEX works_type_idx ON openalex.works (type);
CREATE INDEX works_cited_by_count_idx ON openalex.works (cited_by_count);
CREATE INDEX works_is_oa_idx ON openalex.works_open_access (is_oa);
CREATE INDEX works_oa_status_idx ON openalex.works_open_access (oa_status);
CREATE INDEX works_authorships_work_id_idx ON openalex.works_authorships (work_id);
CREATE INDEX works_authorships_author_id_idx ON openalex.works_authorships (author_id);
CREATE INDEX works_concepts_work_id_idx ON openalex.works_concepts (work_id);
CREATE INDEX works_concepts_concept_id_idx ON openalex.works_concepts (concept_id);
CREATE INDEX works_topics_work_id_idx ON openalex.works_topics (work_id);
CREATE INDEX works_topics_topic_id_idx ON openalex.works_topics (topic_id);
CREATE INDEX works_mesh_work_id_idx ON openalex.works_mesh (work_id);
CREATE INDEX works_keywords_work_id_idx ON openalex.works_keywords (work_id);
CREATE INDEX works_locations_work_id_idx ON openalex.works_locations (work_id);
CREATE INDEX works_primary_location_work_id_idx ON openalex.works_primary_location (work_id);
CREATE INDEX works_best_oa_location_work_id_idx ON openalex.works_best_oa_location (work_id);
CREATE INDEX works_referenced_works_work_id_idx ON openalex.works_referenced_works (work_id);
CREATE INDEX works_related_works_work_id_idx ON openalex.works_related_works (work_id);
CREATE INDEX works_grants_work_id_idx ON openalex.works_grants (work_id);
CREATE INDEX works_grants_funder_id_idx ON openalex.works_grants (funder_id);
CREATE INDEX works_counts_by_year_work_id_idx ON openalex.works_counts_by_year (work_id);
CREATE INDEX works_ids_work_id_idx ON openalex.works_ids (work_id);
CREATE INDEX works_ids_doi_idx ON openalex.works_ids (doi);
CREATE INDEX works_sdg_work_id_idx ON openalex.works_sustainable_development_goals (work_id);
