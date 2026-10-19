# TileSense analytics (dbt, Postgres)

Dimensional layer over the telemetry tables from `server/migrations/`.
Read-only against `public`; builds into its own schemas. Never put models in
`server/migrations/` (deploy.sh applies that to production).

    cp profiles.yml.example ~/.dbt/profiles.yml   # then set DBT_PG_* env vars
    pip install "dbt-postgres>=1.9,<2" "dbt-core>=1.9,<1.13"
    dbt deps
    dbt build           # first run: builds upstream views, then the snapshot
    dbt build -s +snap_client_traits   # scheduled snapshot job; never --full-refresh it

Local database: `docker run -d --name tilesense-dbt-pg -e POSTGRES_DB=tilesense
-e POSTGRES_USER=tilesense -e POSTGRES_PASSWORD=devpassword -p 5433:5432 postgres:16`,
apply `server/migrations/000*.sql`, load `dev/seed_telemetry.sql`, and set
`DBT_PG_PORT=5433`.

Layers: staging (1:1, views) -> intermediate -> marts/core (dims + facts).
Snapshots: snap_client_traits (SCD2 on trait flips).
Not included yet: fct_events, fct_matches, dim_session, dim_date, sim_* models.
`ip_prefix`/`ip_hmac` are intentionally never selected past the source.
