-- Build BM25 FTS indexes on each domain's documents table.
-- DuckDB FTS extension creates a separate `fts_<schema>_<table>` schema with the index.
-- Run after any bulk ingest. PRAGMA is per-domain because FTS does not support cross-schema indexes.

INSTALL fts;
LOAD fts;

PRAGMA create_fts_index('devin.documents',       'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);
PRAGMA create_fts_index('docker.documents',      'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);
PRAGMA create_fts_index('linux.documents',       'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);
PRAGMA create_fts_index('k8s.documents',         'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);
PRAGMA create_fts_index('methodology.documents', 'source_id', 'content_md', stemmer='porter', stopwords='english', overwrite=1);
