# Data Catalog: Gold Layer

Business-facing description of every gold view. These are the objects
analysts and reports should query -- bronze and silver are internal ETL
staging layers.

---

## gold.dim_members

Purpose: one row per member (homeowner/applicant), attributes for
segmentation and profiling.

| Column | Type | Description |
|---|---|---|
| member_key | INT | Surrogate key, unique per row. |
| member_id | INT | Natural key from the source Member Management System. |
| fullname, firstname, lastname, middle_name, title | NVARCHAR | Name fields. `title` normalized to Mr./Mrs./Ms./n/a. |
| sex | NVARCHAR | 'Male' / 'Female' / 'n/a'. ~80% of source rows had this blank -- treat this attribute as low-coverage. |
| social_status | NVARCHAR | Married / Single / Widow / 'n/a'. |
| date_of_birth | DATE | Nullable; blank in source for many rows. |
| age | INT | Derived from date_of_birth as of today; NULL if date_of_birth is NULL. |
| address | NVARCHAR | Free-text home address. |
| project_key | INT | FK to gold.dim_projects -- the subdivision/housing project the member belongs to. |
| contact_no | NVARCHAR | Free-text phone number, not standardized to a fixed format. |
| occupation, religion | NVARCHAR | Free text. |
| monthly_income | DECIMAL(12,2) | Self-reported; 0 is a valid (not missing) value in source data. |
| membership_status | NVARCHAR | Active / Inactive / Unknown. ~70% of rows were blank in source and are labeled 'Unknown' rather than assumed Active. |
| waiver_of_rights | BIT | Whether the member signed a waiver of rights. |
| membership_fee_flag, processing_fee_flag | BIT | Whether the member has been marked as having paid these one-time fees (a flag on the member record, separate from -- and possibly out of sync with -- the transaction detail in gold.fact_fees). |
| beneficiary_profile, birth_certificate, reservation_agreement, id_picture, sinumpaang_salaysay, marriage_certificate | BIT | Document-checklist completeness flags. |
| date_encoded | DATE | When the member record was first entered into the source system. |

## gold.dim_projects

Purpose: one row per housing project/subdivision (e.g. BASINEA, IPAG,
LATI II). Built from the distinct set of project names seen across both
customers_info and amortization, since a handful of projects only appear
in one of the two source files.

| Column | Type | Description |
|---|---|---|
| project_key | INT | Surrogate key. |
| project_name | NVARCHAR | e.g. 'BASINEA', 'IPAG', 'LATI II', 'n/a'. |

## gold.fact_fees

Purpose: one row per one-time fee payment (membership fee or processing
fee). Grain: one payment transaction.

| Column | Type | Description |
|---|---|---|
| member_key | INT | FK to gold.dim_members. NULL if the source payment record had no resolvable member. |
| fee_type | NVARCHAR | 'Membership Fee' or 'Processing Fee'. |
| amount | DECIMAL(12,2) | Amount paid. |
| payed_date | DATE | Date of payment. |
| control_no | NVARCHAR | Receipt/OR control number. Cleaned of embedded line breaks present in ~1% of source rows. |
| remarks | NVARCHAR | Free-text notes from staff. |

Known gap: ~1 membership fee row and ~7 processing fee rows have no
resolvable member and will appear with `member_key = NULL`. See
`tests/quality_checks_silver.sql` to re-identify these after each load.

## gold.fact_amortization

Purpose: one row per member, per project, per due month -- the core
recurring-payment fact table, unpivoted from the wide monthly-columns
format in the source system.

| Column | Type | Description |
|---|---|---|
| member_key | INT | FK to gold.dim_members. |
| project_key | INT | FK to gold.dim_projects. |
| amort_year | INT | Calendar year of the due amount. |
| month_number | TINYINT | 1-12. |
| month_name | NVARCHAR | 'January'..'December'. |
| period_start_date | DATE | First day of the due month, for time-series charting. |
| amount_due | DECIMAL(12,2) | Amount due for the month (excludes penalty). |
| amount_penalty | DECIMAL(12,2) | Penalty charged for the month, if any. |
| amount_due_with_penalty | DECIMAL(12,2) | amount_due + amount_penalty. |
| payed_date | DATE | Date payment was recorded, NULL if unpaid as of last load. |
| is_paid | BIT | Derived: 1 if payed_date is not NULL. |
| control_no, remarks | NVARCHAR | Receipt reference / staff notes for the month. |
| not_counted | BIT | A source-system exclusion flag set by association staff for specific member/year records (e.g. a waived or voided year). This is NOT the same thing as "unpaid" -- always filter on this explicitly if a report needs to exclude excluded records, don't assume `is_paid = 0` covers it. |

---

## Data Quality Notes (apply across the gold layer)

1. **`FULLNAME` in the amortization source file is mislabeled** -- it holds
   numeric member IDs, not names. This is resolved transparently in silver
   (see `documents/naming_conventions.md`), but if the source system is ever
   re-exported with a genuine "FULLNAME" text column added, the bronze DDL
   and silver load logic for `mms_amortization` will need to be revisited.
2. **`sex` and `membership_status` are mostly blank** in the source
   (~80% and ~70% respectively). Don't build headline KPIs on these fields
   without first checking coverage in the current load.
3. **Not every fee/amortization row resolves to a member** -- a small
   number of source rows have a blank or unmatched member reference.
   These surface as `member_key IS NULL` in the fact views; decide per
   report whether to exclude or flag them rather than silently dropping them.
