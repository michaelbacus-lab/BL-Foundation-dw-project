# Naming Conventions

This document defines the naming conventions used across schemas, tables,
views, columns, and stored procedures in the HomeownersDW warehouse.

## General Principles

- **Case:** `snake_case`, all lowercase, words separated by underscores.
- **Language:** English for all object/column names, even though the source
  spreadsheets mix in a few Filipino terms (e.g. "Sinumpaang Salaysay") for
  document names -- those are kept as-is since they name a specific legal
  document, not a translatable business term.
- **Reserved words:** avoid SQL reserved words as identifiers.
- **Source system tag:** every bronze/silver table is prefixed with the
  three-letter source system tag `mms` (Member Management System), the
  single system that exports all four CSVs. This mirrors multi-source
  projects where the prefix disambiguates which system a table came from,
  and keeps the convention future-proof if a second source system is added
  later (e.g. an accounting system tagged `acc`).

## Schema Layers

| Schema   | Purpose                                                            |
|----------|---------------------------------------------------------------------|
| `bronze` | Raw, unmodified data loaded directly from source CSVs.             |
| `silver` | Cleansed, standardized, de-duplicated, and typed data.              |
| `gold`   | Business-ready star schema (dimensions and facts) for reporting.   |

## Table Naming

**Bronze & Silver:** `<schema>.<source_system>_<entity>`
- `bronze.mms_customers_info`
- `silver.mms_membership_fee`
- `silver.mms_amortization_detail` -- suffix `_detail` signals this table is
  at a different (finer) grain than its bronze counterpart, since it is
  unpivoted from 12 wide month-blocks into one row per member/project/year/month.

**Gold:** `<schema>.<category>_<entity>`
| Category | Meaning                     | Example                 |
|----------|------------------------------|--------------------------|
| `dim`    | Dimension table (view)       | `gold.dim_members`       |
| `fact`   | Fact table (view)            | `gold.fact_amortization` |

## Column Naming

- Primary keys: `<entity>_id` for natural/source keys (`member_id`,
  `memfee_id`, `amortization_id`); `<entity>_key` for gold-layer surrogate
  keys generated with `ROW_NUMBER()` (`member_key`, `project_key`).
- Boolean flags: named for the thing they assert, typed as `BIT` in silver
  (`waiver_of_rights`, `paid`, `is_paid`), not `is_` prefixed unless the
  column is derived rather than sourced directly (e.g. `is_paid` is derived
  from `payed_date IS NOT NULL`, but `paid` is a literal source flag).
- Dates: `<event>_date` (`payed_date`, `date_of_birth`); technical/audit
  timestamps use `date_created`, `date_updated`, and `dwh_create_date` for
  the ETL load timestamp added in silver.
- Amounts: `amount_<qualifier>` where more than one amount exists in the same
  table (`amount_due`, `amount_penalty`), otherwise just `amount`.
- Foreign keys resolved during cleansing keep the same name as the
  referenced table's key (`member_id` in `silver.mms_membership_fee` points
  to `silver.mms_customers_info.member_id`).

## Stored Procedures

`<schema>.load_<schema>`, e.g. `bronze.load_bronze`, `silver.load_silver`.
Each procedure truncates and reloads its own schema's tables end to end.

## Known Source-Naming Quirks (intentionally normalized away)

These are naming issues in the original CSVs that are corrected during
ingestion rather than carried forward, and are documented here so the
history isn't lost:

| Source column                | Issue                                          | Resolved as                          |
|-------------------------------|-------------------------------------------------|----------------------------------------|
| `FULLNAME` (amortization.csv) | Contains numeric member IDs, not names          | `member_ref` (bronze) -> `member_id` (silver) |
| `Mr Mrs`                      | No underscore, ambiguous                        | `title`                                |
| `REVERVATION AGREEMENT`       | Misspelling of "Reservation"                    | `reservation_agreement`                |
| `MEMBERSHIP FEE` / `PROCESSING FEE` in customers_info.csv | Same names as the separate fee transaction CSVs, but these are boolean flags, not amounts | `membership_fee_flag`, `processing_fee_flag` |
| `JUNE`/`JULY` due columns vs. `JUN`/`JUL` payment columns | Inconsistent month abbreviations within the same file | Normalized to `jan`..`dec` everywhere |
