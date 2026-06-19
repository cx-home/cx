# ETL Project Conventions — CX Edition

**Version:** 1.0
**Format:** CX-standardized edition (CX config, CX field maps)
**Companion:** `etl_conventions.md` for the base edition (TOML config, Excel field maps)
**CX format reference:** https://github.com/cx-home/cx

This is the CX-standardized edition. Sections 1–3 and 6–11 are identical to the base
edition. Sections 4 (Configuration) and 5 (Field Maps) differ — they use CX format
with the CX Document API and CXPath for navigation and querying.

---

## Table of Contents

1. [Project Structure & File Naming](#1-project-structure--file-naming)
2. [Class & Function Naming Conventions](#2-class--function-naming-conventions)
3. [Layer Responsibilities & Boundaries](#3-layer-responsibilities--boundaries)
4. [Configuration](#4-configuration)
5. [Field Maps](#5-field-maps)
6. [Operational Concerns](#6-operational-concerns)
7. [Pipeline & Job Orchestration](#7-pipeline--job-orchestration)
8. [Data Flow & Performance](#8-data-flow--performance)
9. [Testing](#9-testing)
10. [Documentation Requirements](#10-documentation-requirements)
11. [Decisions Made](#11-decisions-made)

---

## 1. Project Structure & File Naming

### Directory Layout

```
etl/
├── extractors/
│   ├── base_extractor.py
│   └── {source_system}/
│       ├── __init__.py
│       ├── {source_system}_extractor.py
│       ├── _api_client.py              # only if needed
│       ├── _db_client.py               # only if needed
│       ├── _ftp_client.py              # only if needed
│       └── _queries.py                 # SQL constants, only if needed
│
├── transformers/
│   ├── base_transformer.py
│   ├── {target_domain}_transformer.py
│   └── {target_domain}_merger.py       # only if merge logic is complex or reused
│
├── loaders/
│   ├── base_loader.py
│   ├── postgres_loader.py
│   ├── s3_loader.py
│   └── file_loader.py
│
├── pipelines/
│   └── {target_domain}_{action}_pipeline.py
│
├── jobs/
│   └── {trigger}_{target_domain}_job.py
│
├── config/
│   ├── base/                           # typed dataclass shapes
│   │   ├── {system_name}_config.py
│   │   └── ...
│   ├── systems/
│   │   ├── sources/
│   │   │   ├── {source_system}.cx      # one file per system, environments inside
│   │   │   └── ...
│   │   └── targets/
│   │       ├── {target_system}.cx
│   │       └── ...
│   ├── field_maps/
│   │   ├── {target_domain}_field_map.cx
│   │   └── ...
│   ├── lookup_data/                    # external reference data
│   │   └── ...
│   └── config_loader.py
│
├── shared/
│   ├── results.py                      # PipelineResult, JobResult types
│   ├── exceptions.py                   # ETL-specific exception types
│   ├── observability.py                # logging, metrics, tracing helpers
│   ├── retry.py                        # retry decorators
│   └── watermarks.py                   # incremental load state
│
├── tools/
│   ├── field_map_validator.py
│   ├── config_validator.py
│   └── ...
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│
└── docs/
    ├── systems/                        # one README per source/target system
    │   └── {system_name}.md
    ├── pipelines/                      # one README per pipeline
    │   └── {pipeline_name}.md
    └── adr/                            # architecture decision records
        └── 0001-{title}.md
```

### File Naming Rules

| Layer | Pattern | Examples |
|---|---|---|
| Extractor | `{source_system}_extractor.py` | `salesforce_extractor.py`, `system_x_extractor.py` |
| Internal client | `_{transport}_client.py` | `_api_client.py`, `_db_client.py`, `_ftp_client.py` |
| SQL constants | `_queries.py` | one file per system, internal only |
| Transformer | `{target_domain}_transformer.py` | `customer_transformer.py`, `order_transformer.py` |
| Merger | `{target_domain}_merger.py` | `customer_merger.py` — only when complex or reused |
| Loader | `{destination}_loader.py` | `postgres_loader.py`, `s3_loader.py` |
| Pipeline | `{target_domain}_{action}_pipeline.py` | `customer_sync_pipeline.py`, `invoice_export_pipeline.py` |
| Job | `{trigger}_{target_domain}_job.py` | `nightly_customer_job.py`, `on_demand_invoice_job.py` |
| Config (base) | `{system_name}_config.py` | `system_x_config.py`, `salesforce_config.py` |
| Config (system) | `{system_name}.cx` | `system_x.cx`, `postgres.cx` |
| Field map | `{target_domain}_field_map.cx` | `customers_field_map.cx`, `orders_field_map.cx` |

### Key Structural Rules

- **Extractors** organized by **source system** — one subdirectory per system
- **Transformers** organized by **target domain** — flat, no subdirectories by default
- **Loaders** organized by **destination** — flat, no subdirectories by default
- **Field maps** organized by **target domain** — a single field map can draw from multiple source systems; source is a per-row attribute
- **Config** organized by **system** — one file per system, environments as nested sections inside
- Internal clients and queries prefixed with `_` — not for use outside the extractor package
- Add subdirectories only when a file grows large enough to warrant it
- Schema versioning is opt-in per system, not applied globally

---

## 2. Class & Function Naming Conventions

### Fixed Verbs by Layer

Each layer has a canonical verb that never drifts:

| Layer | Public verb | Notes |
|---|---|---|
| Extractor | `extract_*()` | Named by what data is returned, not how |
| Internal client | `get_*()`, `query_*()`, `download_*()` | Named by transport action |
| Transformer | `transform()` | Single entry point; private helpers below |
| Loader | `load()` | Variants: `upsert()`, `load_partitioned()` when distinction matters |
| Pipeline | `run()` | Always `run()`, no exceptions |
| Job | `run()` | Always `run()`, no exceptions |

### Extractor Classes

One public class per system. Methods named by **what** data is returned, never by **how** it is fetched. The pipeline never knows whether data came from an API, database, FTP, or file.

```python
class SystemXExtractor(BaseExtractor):
    def __init__(self, config: SystemXConfig):
        self.config = config
        self._api = SystemXApiClient(config.api)
        self._db = SystemXDbClient(config.db)
        self._ftp = SystemXFtpClient(config.ftp)

    def extract_customers(self) -> pd.DataFrame: ...
    def extract_orders(self, since: date) -> pd.DataFrame: ...
    def extract_inventory(self) -> pd.DataFrame: ...
    def extract_report(self, report_date: date) -> pd.DataFrame: ...
```

### Internal Client Classes

Named by transport mechanism. Own all transport-level details — endpoints, SQL, file paths, auth, pagination.

```python
class SystemXApiClient:
    def get_customers(self) -> list[dict]: ...
    def get_invoices(self, since: date) -> list[dict]: ...

class SystemXDbClient:
    def query_orders(self, since: date) -> list[dict]: ...
    def query_inventory(self) -> list[dict]: ...

class SystemXFtpClient:
    def download_report(self, filename: str) -> io.BytesIO: ...
    def list_reports(self, directory: str) -> list[str]: ...
```

### Transformer Classes

Single public `transform()` entry point. All logic decomposed into private `_` methods. Transformers are pure — DataFrame in, DataFrame out, no I/O of any kind.

```python
class CustomerTransformer(BaseTransformer):
    def __init__(self, field_map: FieldMap):
        self.field_map = field_map

    def transform(self, df: pd.DataFrame) -> TransformResult: ...
    def _normalize_names(self, df: pd.DataFrame) -> pd.DataFrame: ...
    def _standardize_phone(self, df: pd.DataFrame) -> pd.DataFrame: ...
    def _derive_customer_tier(self, df: pd.DataFrame) -> pd.DataFrame: ...
```

### Loader Classes

Single public `load()` entry point. Variants are additive — `upsert()`, `load_partitioned()` — not replacements.

```python
class PostgresLoader(BaseLoader):
    def __init__(self, config: PostgresConfig):
        self.engine = create_engine(config.connection_string)

    def load(self, df: pd.DataFrame, table: str) -> LoadResult: ...
    def upsert(self, df: pd.DataFrame, table: str, key_columns: list[str]) -> LoadResult: ...
```

### Pipeline Classes

Owns assembly of extractors, transformers, and loaders. Private `_merge()` for multi-source joins.

```python
class CustomerSyncPipeline:
    def __init__(
        self,
        extractor: BaseExtractor,
        transformer: BaseTransformer,
        loader: BaseLoader,
    ):
        ...

    def run(self, since: date | None = None) -> PipelineResult: ...
    def _merge(self, *dfs: pd.DataFrame) -> pd.DataFrame: ...
```

### Job Classes

Owns orchestration — instantiates config, resolves system+environment, injects into pipelines, owns retry policy and alerting.

```python
class NightlyCustomerJob:
    def run(self) -> JobResult: ...
```

---

## 3. Layer Responsibilities & Boundaries

### Responsibility Matrix

| Layer | Owns | Never touches |
|---|---|---|
| Internal client | Transport details — endpoints, SQL, file paths, auth, pagination, transport-level retries | DataFrames, business logic |
| Extractor | Converts raw client output to DataFrames, exposes named methods by domain | Transform logic, load logic, business validation |
| Transformer | All business logic — cleaning, derivation, field mapping, validation, derivation rules | I/O of any kind, extractors, loaders |
| Loader | Writing DataFrames to a destination, destination-specific retries and conflict handling | Transform logic, extract logic |
| Pipeline | Assembly — wires extractors, transformers, loaders; owns merge logic and pipeline-level retries | Business logic, transport details, config resolution |
| Job | Orchestration — resolves config, injects into pipelines, owns scheduling, logging, alerting, watermarks | Data logic of any kind |

### The Clean Call Chain

```
Job.run()
 └── Pipeline.run()
      ├── Extractor.extract_*()
      │    └── Client.get_*() / query_*() / download_*()
      ├── Pipeline._merge()           # only if multiple sources
      ├── Transformer.transform()
      └── Loader.load()
```

No layer calls upward. No layer skips a level.

### Multi-Source Pipelines

When a pipeline draws from multiple extractors, merge/join logic lives on the pipeline as a private method — not in the transformer. The transformer always receives one clean combined DataFrame.

```python
class CustomerSyncPipeline:
    def run(self, since: date | None = None) -> PipelineResult:
        system_x_df = self.system_x.extract_customers()
        salesforce_df = self.salesforce.extract_contacts()
        combined = self._merge(system_x_df, salesforce_df)
        result = self.transformer.transform(combined)
        load_result = self.loader.load(result.clean_df, table="customers")
        return PipelineResult.from_parts(result, load_result)
```

If merge logic becomes complex or is reused across pipelines, promote it to a dedicated `{target_domain}_merger.py` in `transformers/`.

### Schema Version Variants

When a source system has genuinely divergent schemas across environments, version-specific components are resolved at the job level. The pipeline shape never changes.

```python
class NightlyCustomerJob:
    def run(self) -> JobResult:
        config = ConfigLoader()
        src = config.source("system_x", "prod")

        if src.schema_version == "v1":
            from extractors.system_x.v1 import SystemXExtractor
            from transformers.v1 import CustomerTransformer
        else:
            from extractors.system_x.v2 import SystemXExtractor
            from transformers.v2 import CustomerTransformer

        return CustomerSyncPipeline(
            extractor=SystemXExtractor(src),
            transformer=CustomerTransformer(field_map=load_field_map("customers")),
            loader=PostgresLoader(config.target("postgres", "test")),
        ).run()
```

Schema versioning is opt-in per system — only applied when a system's schema genuinely diverges. Systems without schema versioning have no version subdirectory.

---

## 4. Configuration

### Principle

> The pipeline should read like a business process, not a technical specification.

### Two Parameter Categories

| Type | Definition | Owned by | Examples |
|---|---|---|---|
| **Business params** | Vary by business logic | Pipeline passes to extractor | `since: date`, `region: str`, `status: str` |
| **Transport params** | Vary by implementation | Extractor / client owns internally | endpoints, SQL, file paths, page size, headers |

The pipeline never passes endpoints, SQL, file paths, or pagination to an extractor.

### Config Is Per System × Environment

A pipeline may extract from `system_x` prod and load to `postgres` test simultaneously. Environment is not a pipeline-level setting — it is resolved independently per system at the job level.

```python
CustomerSyncPipeline(
    extractor=SystemXExtractor(config.source("system_x", "prod")),
    loader=PostgresLoader(config.target("postgres", "test")),
).run()
```

### Config File Format — CX

System config uses CX format (`.cx` files). CX advantages for this use case:

- Bracket syntax is unambiguous — no indentation sensitivity, no type coercion surprises
- Native typed attributes — `port=8080` is int, `debug=false` is bool, no quoting required
- Comments supported inline
- Hierarchical structure maps naturally to nested system config
- Document API (`at()`, `attr()`, `get()`) provides clean programmatic access
- CXPath enables querying config by attribute when introspection is needed
- Immutable document model — safe to share parsed config across threads

### One File Per System

One CX file per source or target system. Environments are nested elements inside. Adding an environment touches one file per affected system, not the entire tree.

```cx
[; config/systems/sources/system_x.cx ]

[system_x

  [meta
    description='Legacy ERP and warehouse system'
    owner='platform-data-team'
    runbook='docs/systems/system_x.md'
  ]

  [defaults
    [; values that apply to all environments unless overridden ]
    api_version=v2
    page_size=100
  ]

  [environments

    [environment name=dev
      schema_version=v1
      [api
        base_url='http://localhost:8000'
        api_version=v1                         [; override ]
        api_key_ref=SYSTEM_X_API_KEY
        page_size=10                           [; override ]
      ]
      [db
        connection_string_ref=SYSTEM_X_DB_URL
        schema=legacy_schema
      ]
      [ftp
        host=localhost
        username_ref=SYSTEM_X_FTP_USER
        password_ref=SYSTEM_X_FTP_PASS
        report_dir='/mnt/test_drops'
      ]
    ]

    [environment name=staging
      schema_version=v1
      [api
        base_url='https://staging-api.systemx.com'
        api_key_ref=SYSTEM_X_API_KEY
      ]
      [db
        connection_string_ref=SYSTEM_X_DB_URL
        schema=legacy_schema
      ]
      [ftp
        host=sftp-staging.systemx.com
        username_ref=SYSTEM_X_FTP_USER
        password_ref=SYSTEM_X_FTP_PASS
        report_dir='/exports/daily'
      ]
    ]

    [environment name=prod
      schema_version=v2
      [api
        base_url='https://api.systemx.com'
        api_key_ref=SYSTEM_X_API_KEY
      ]
      [db
        connection_string_ref=SYSTEM_X_DB_URL
        schema=new_schema
      ]
      [ftp
        host=sftp.systemx.com
        username_ref=SYSTEM_X_FTP_USER
        password_ref=SYSTEM_X_FTP_PASS
        report_dir='/exports/daily'
      ]
    ]

  ]

]
```

### Defaults and Overrides

The `[defaults]` element provides values that apply to all environments. Each `[environment]` element may override individual attributes or child elements. The loader merges defaults with the requested environment, environment values winning on conflict.

### Secrets Convention

Config files contain only **references** to secrets, never values. The `_ref` suffix on any attribute signals: resolve this environment variable name at runtime.

```python
# config_loader.py resolves _ref attrs automatically
def _resolve_attr(self, el, name: str) -> str:
    ref_value = el.attr(name + "_ref")
    if ref_value is not None:
        resolved = os.getenv(ref_value)
        if resolved is None:
            raise ConfigError(f"Required env var {ref_value} not set (referenced as {name}_ref)")
        return resolved
    direct = el.attr(name)
    if direct is None:
        raise ConfigError(f"Missing required attribute: {name}")
    return direct
```

Secrets live entirely outside the project — environment variables, AWS Secrets Manager, HashiCorp Vault, or equivalent. Never committed to version control.

### Config Validation at Load Time

The config loader fails fast on invalid configuration. A missing required attribute, an unset secret reference, or a type mismatch raises `ConfigError` immediately at job startup, never partway through a run.

```python
# shared/exceptions.py
class ConfigError(Exception):
    """Configuration is missing, invalid, or references missing secrets."""

# config/config_loader.py
import cxlib

class ConfigLoader:
    def source(self, system: str, environment: str) -> SystemConfig:
        try:
            doc = cxlib.parse_file(f"config/systems/sources/{system}.cx")
            system_root = doc.at(system)
            if system_root is None:
                raise ConfigError(f"Top-level [{system}] not found in {system}.cx")
            env_el = self._select_environment(system_root, environment)
            merged = self._merge_with_defaults(system_root, env_el)
            config = self._build_typed_config(system, merged)
            config.validate()
            return config
        except (cxlib.ParseError, KeyError, TypeError, ValueError) as e:
            raise ConfigError(f"Failed to load {system}/{environment}: {e}") from e

    def _select_environment(self, system_root, environment: str):
        env = system_root.select(f"environments/environment[@name={environment}]")
        if env is None:
            raise ConfigError(f"Environment '{environment}' not defined")
        return env
```

### Config Base Classes

Typed dataclasses define the shape. Values are populated from CX at runtime. Each config class implements a `validate()` method that runs at load time.

```python
@dataclass(frozen=True)
class SystemXApiConfig:
    base_url: str
    api_version: str
    api_key: str
    page_size: int = 100

    def validate(self) -> None:
        if not self.base_url.startswith(("http://", "https://")):
            raise ConfigError(f"Invalid api.base_url: {self.base_url}")
        if self.page_size < 1 or self.page_size > 10000:
            raise ConfigError(f"api.page_size out of range: {self.page_size}")

@dataclass(frozen=True)
class SystemXConfig:
    schema_version: str
    api: SystemXApiConfig
    db: SystemXDbConfig
    ftp: SystemXFtpConfig

    def validate(self) -> None:
        self.api.validate()
        self.db.validate()
        self.ftp.validate()
        if self.schema_version not in ("v1", "v2"):
            raise ConfigError(f"Unknown schema_version: {self.schema_version}")
```

### SQL Lives in the Client

```python
# extractors/system_x/_queries.py
ORDERS_QUERY_V1 = """
    SELECT order_id, cust_id, order_total, stat_cd, create_dt
    FROM legacy_schema.ORDERS
    WHERE create_dt >= :since
"""

ORDERS_QUERY_V2 = """
    SELECT id, customer_id, total, status, created_at
    FROM new_schema.orders
    WHERE created_at >= :since
"""

# _db_client.py selects query by schema version — pipeline never sees SQL
class SystemXDbClient:
    def query_orders(self, since: date) -> list[dict]:
        query = ORDERS_QUERY_V1 if self.schema == "legacy_schema" else ORDERS_QUERY_V2
        return self.conn.execute(query, {"since": since})
```

### Multi-Environment Matrix

A pipeline may extract from one environment and load to another. The job is the only place that decides this — pipelines and below are environment-agnostic.

```python
class MigrationCustomerJob:
    """Migrates customers from legacy prod to new prod."""

    def run(self) -> JobResult:
        config = ConfigLoader()
        return CustomerSyncPipeline(
            extractor=SystemXExtractor(config.source("system_x", "prod")),
            transformer=CustomerTransformer(field_map=load_field_map("customers")),
            loader=PostgresLoader(config.target("postgres_new", "prod")),
        ).run()
```

---

## 5. Field Maps

### Purpose

Field maps define what the **target domain** needs and where to find it across one or more source systems. They serve two roles simultaneously:

- **Runtime config** — drives transformer field mapping, type casting, validation, and transform dispatch, read directly via the CX Document API
- **Documentation** — human-reviewable audit trail of all field-level decisions, exportable to Excel for stakeholder review

Unmapped source fields are ignored. The target defines scope, not the source.

### Format — CX

Field maps are CX files. One file per **target domain**, checked into version control alongside code. A single field map can draw from multiple source systems — source is a per-element attribute, not a file-level concern. Read at runtime using the CX Document API.

```python
import cxlib

doc = cxlib.parse_file("config/field_maps/customers_field_map.cx")
fields      = doc.find_all("field")
merges      = doc.find_all("merge")
splits      = doc.find_all("split")
constraints = doc.find_all("constraint")
```

CXPath enables filtered access — load only fields relevant to the active schema version of a given system:

```python
active = doc.select_all(
    f"//field[@source_system={system} and "
    f"(not(@schema_version) or @schema_version={schema_version})]"
)
```

### Why CX over Excel for Field Maps

The structural argument: a field map is fundamentally hierarchical, not flat. A single field has one transform but possibly multiple validations, FK references, lineage across schema versions, and free-form documentation. In Excel this forces flattening into many sparse columns or encoded strings. In CX each `[field]` element holds exactly the children it needs — multiple `[validation]` children, optional `[fk_ref]`, optional `[lineage]`, free-form notes as block content. Absence is meaningful, not just an empty cell.

The full tradeoff analysis appears in Section 11 (Decisions Made).

### Schema Version

`schema_version` is an optional attribute on each `[field]`, `[merge]`, or `[split]` element. Absent = applies to all versions of that source system. Present = applies only to that version.

### File Structure

```cx
[; config/field_maps/customers_field_map.cx ]

[field_map target_domain=customers

  [meta
    target_system=postgres
    target_table=customers
    schema_versions='v1,v2'
    last_reviewed=2026-03-01
    reviewed_by='Jane Smith, John Dev'
    status='v1 active, v2 in progress'
  ]

  [fields

    [; Simple rename — no transform children needed ]
    [field target=customer_id source_system=system_x source_field=customer_id
      schema_version=v2
      source_type=string target_type=string
      required=true nullable=false pk=true fk=false
    ]

    [; Cast with lineage across schema versions ]
    [field target=customer_id source_system=system_x source_field=cust_id
      schema_version=v1
      source_type=integer target_type=string
      required=true nullable=false pk=true fk=false
      [transform type=cast]
      [lineage
        [source system=system_x field=cust_id schema=v1
          'Legacy integer key introduced 2008, cast to string for new system']
      ]
    ]

    [; Multiple validations on one field ]
    [field target=phone source_system=system_x source_field=ph_num
      source_type=string target_type=string
      required=false nullable=true pk=false fk=false
      [transform type=standardize_phone]
      [validation type=regex pattern='^\+?[\d\s\-\(\)]{7,15}$' on_failure=flag]
      [validation type=range min=7 max=15 on_failure=flag
        'Validates normalized length after standardize_phone runs']
    ]

    [; Lookup transform with default and lookup_miss handling ]
    [field target=customer_tier source_system=system_x source_field=tier_cd
      source_type=string target_type=string
      required=false nullable=true default_value=unknown
      [transform type=lookup table=tier_codes on_failure=flag]
    ]

    [; FK reference with constraint ]
    [field target=order_id source_system=system_x source_field=order_id
      source_type=integer target_type=integer
      required=true nullable=false pk=false fk=true
      [fk_ref table=orders field=order_id]
      [transform type=cast]
      [validation type=referential on_failure=reject
        'Must exist in orders table before customer record is loaded']
    ]

    [; Email validation, applies to all versions of salesforce ]
    [field target=email source_system=salesforce source_field=Email
      source_type=string target_type=string
      required=false nullable=true pk=false fk=false
      [transform type=trim]
      [validation type=regex pattern='^[^@]+@[^@]+\.[^@]+$' on_failure=flag]
    ]

    [; Complex transform deferred to code ]
    [field target=customer_tier source_system=system_x source_field=tier_cd
      schema_version=v2
      source_type=string target_type=string
      required=false nullable=true on_failure=flag
      [transform type=code fn=derive_tier
        'Multi-factor derivation from order history and region.
         See _derive_tier() in customer_transformer.py.']
      [validation type=lookup table=tier_codes on_failure=flag]
    ]

  ]

  [merges

    [; Many-to-one: name fields with edge cases ]
    [merge target=full_name source_system=system_x schema_version=v1
      target_type=string required=true nullable=false on_failure=flag
      [sources
        [source field=first_nm]
        [source field=last_nm]
        [source field=suffix optional=true]
      ]
      [transform type=code fn=build_full_name
        'Handles null middle name, generational suffixes (Jr, III etc).
         See _build_full_name() in customer_transformer.py']
    ]

    [; Many-to-one: simple concat ]
    [merge target=full_address source_system=system_x
      target_type=string required=false nullable=true on_failure=flag
      [sources
        [source field=addr1]
        [source field=addr2 optional=true]
        [source field=city]
      ]
      [transform type=concat separator=newline]
    ]

  ]

  [splits

    [; One-to-many: address parsing ]
    [split source_field=full_address source_system=system_x schema_version=v1
      required=false on_failure=flag
      [targets
        [target field=street type=string]
        [target field=city   type=string]
        [target field=state  type=string nullable=true]
        [target field=zip    type=string nullable=true]
      ]
      [transform type=code fn=parse_address
        'Handles PO boxes, suite numbers, international formats.
         See _parse_address() in address_transformer.py']
    ]

  ]

  [constraints

    [; Cross-field constraint ]
    [constraint name=valid_date_range type=cross_field on_failure=reject
      [fields
        [field ref=start_date]
        [field ref=end_date]
      ]
      [rule 'start_date <= end_date']
    ]

    [; Complex cross-field deferred to code ]
    [constraint name=status_product_match type=cross_field on_failure=flag
      [fields
        [field ref=status]
        [field ref=product_type]
      ]
      [rule type=code fn=validate_status_product
        'Active status requires product_type non-null and approved.
         See _validate_status_product() in customer_transformer.py']
    ]

  ]

  [lookups

    [lookup_table name=tier_codes
      [entry source=A target=Gold]
      [entry source=B target=Silver]
      [entry source=C target=Bronze]
    ]

    [lookup_table name=status_codes
      [entry source=1 target=active]
      [entry source=0 target=inactive]
      [entry source=9 target=suspended]
    ]

    [; Reference an external lookup source instead of inline entries ]
    [lookup_table name=country_codes
      [external source='file:config/lookup_data/iso3166.csv' refresh=static]
    ]

    [lookup_table name=exchange_rates
      [external source='db:reference.exchange_rates' refresh=hourly]
    ]

  ]

]
```

### Type Vocabulary

Legal values for `source_type` and `target_type` attributes:

| Type | Description |
|---|---|
| `string` | Text |
| `integer` | Whole number |
| `float` | Floating-point number |
| `decimal` | Fixed-precision decimal (use for currency) |
| `bool` | True/false |
| `date` | Calendar date, no time |
| `datetime` | Date and time, with timezone |
| `timestamp` | Date and time, UTC |
| `bytes` | Binary data |
| `json` | Nested structured data |

`default_value` is interpreted in the context of `target_type`. CX auto-types unquoted attribute values, so `default_value=0` for an integer target is the int 0; `default_value=unknown` is the string "unknown".

### Field Map Element Reference

#### `[field]` — one-to-one mapping

Top-level attributes identify the field and its source. Child elements carry the richer structure.

| Attribute | Required | Description |
|---|---|---|
| `target` | yes | Target field name |
| `source_system` | yes | Source system name |
| `source_field` | yes | Source field name |
| `schema_version` | no | Absent = all versions |
| `source_type` | yes | From type vocabulary |
| `target_type` | yes | From type vocabulary |
| `required` | yes | Must be present in source |
| `nullable` | yes | Can be null in target |
| `pk` | yes | Primary key in target |
| `fk` | yes | Foreign key in target |
| `default_value` | no | Value if source is null or missing |

**`[transform]` child** — at most one per `[field]`

| Attribute | Required | Description |
|---|---|---|
| `type` | yes | `cast`, `trim`, `rename`, `lookup`, `standardize_phone`, `concat`, `code` |
| `table` | when type=lookup | Lookup table name |
| `separator` | when type=concat | `space`, `newline`, `comma` |
| `fn` | when type=code | Function name in transformer |
| `on_failure` | when type=lookup | Behavior when value not found and no default |
| body text | when type=code | Description of logic and location |

**`[validation]` children** — zero or more per `[field]`, applied in document order

| Attribute | Required | Description |
|---|---|---|
| `type` | yes | `regex`, `range`, `lookup`, `referential`, `code` |
| `pattern` | when type=regex | Regex pattern string |
| `min` / `max` | when type=range | Numeric bounds (inclusive) |
| `table` | when type=lookup | Lookup table name |
| `fn` | when type=code | Function name in transformer |
| `on_failure` | yes | `reject`, `flag`, `quarantine`, `halt` |
| body text | optional | Notes on validation intent |

**`[fk_ref]` child** — when `fk=true`

| Attribute | Required |
|---|---|
| `table` | yes |
| `field` | yes |

**`[lineage]` child** — optional, documents source history

Contains one or more `[source system=name field=name schema=ver]` elements with optional body text.

#### `[merge]` — many source fields to one target field

Top-level attributes: `target`, `source_system`, `schema_version` (optional), `target_type`, `required`, `nullable`, `on_failure`.

`[sources]` child contains one `[source field=name optional=bool]` per contributing field.

`[transform]` child has same structure as field-level transform.

#### `[split]` — one source field to many target fields

Top-level attributes: `source_field`, `source_system`, `schema_version` (optional), `required`, `on_failure`.

`[targets]` child contains one `[target field=name type=type nullable=bool]` per output field.

`[transform]` child is always `type=code` with `fn` and body text describing the logic.

#### `[constraint]` — cross-field rules

Top-level attributes: `name` (unique), `type` (`cross_field`), `on_failure`.

`[fields]` child contains one `[field ref=name]` per involved field.

`[rule]` child has body text containing the expression, or `type=code fn=name` when deferred.

#### `[lookup_table]` — reference table

Attribute: `name` — referenced by `[transform type=lookup table=name]` and `[validation type=lookup table=name]`.

Children are either `[entry source=X target=Y]` for inline entries, or a single `[external source=URI refresh=interval]` for externally loaded data.

External `source` URIs:
- `file:path/to/file.csv` — loaded from a CSV file at startup
- `db:schema.table` — loaded from a database table at startup
- `api:url` — loaded from an HTTP endpoint at startup

`refresh` values:
- `static` — loaded once at construction, never refreshed
- `hourly`, `daily` — hint to caching infrastructure for invalidation cadence

### On Failure Behaviors

| Behavior | Meaning |
|---|---|
| `halt` | Stop the pipeline immediately, raise an error |
| `reject` | Drop the row, increment a rejected counter, continue |
| `quarantine` | Send the row to the quarantine destination, continue |
| `flag` | Add a `_flags` column entry, keep the row, continue |

### Lookup Miss Behavior

When a `[transform type=lookup]` encounters a source value not present in the lookup table:

1. If `default_value` is set on the field, the default is used and a `lookup_miss` flag is added
2. If `default_value` is absent, the transform's `on_failure` behavior applies

### How Transformers Consume Field Maps

The transformer reads the CX document at construction. Because field structure is nested, dispatch logic reads cleanly and handles multiple validations per field naturally.

```python
import cxlib

class CustomerTransformer(BaseTransformer):
    def __init__(self, field_map_path: str, source_system: str, schema_version: str = None):
        doc = cxlib.parse_file(field_map_path)

        if schema_version:
            self.fields = doc.select_all(
                f"//field[@source_system={source_system} and "
                f"(not(@schema_version) or @schema_version={schema_version})]"
            )
        else:
            self.fields = doc.select_all(f"//field[@source_system={source_system}]")

        self.merges      = doc.find_all("merge")
        self.splits      = doc.find_all("split")
        self.constraints = doc.find_all("constraint")
        self.lookups     = self._load_lookups(doc)

    def transform(self, df: pd.DataFrame) -> TransformResult:
        result = TransformResult.empty()
        for field in self.fields:
            df, field_result = self._apply_field(df, field)
            result = result.merge(field_result)
        for merge in self.merges:
            df, merge_result = self._apply_merge(df, merge)
            result = result.merge(merge_result)
        for split in self.splits:
            df, split_result = self._apply_split(df, split)
            result = result.merge(split_result)
        for constraint in self.constraints:
            df, constraint_result = self._apply_constraint(df, constraint)
            result = result.merge(constraint_result)
        return TransformResult(clean_df=df, **result.counters)

    def _apply_field(self, df, field):
        # apply transform if present
        t = field.at("transform")
        if t:
            df = self._dispatch_transform(df, field, t)
        # apply all validations in document order
        for v in field.find_all("validation"):
            df = self._dispatch_validation(df, field, v)
        return df, TransformResult.empty()

    def _dispatch_transform(self, df, field, t):
        match t.attr("type"):
            case "cast":              return self._cast(df, field)
            case "trim":              return self._trim(df, field)
            case "rename":            return self._rename(df, field)
            case "lookup":            return self._lookup(df, field, t)
            case "standardize_phone": return self._standardize_phone(df, field)
            case "concat":            return self._concat(df, field, t)
            case "code":              return self._call(t.attr("fn"), df, field)
            case _:                   return df

    def _dispatch_validation(self, df, field, v):
        match v.attr("type"):
            case "regex":       return self._validate_regex(df, field, v)
            case "range":       return self._validate_range(df, field, v)
            case "lookup":      return self._validate_lookup(df, field, v)
            case "referential": return self._validate_fk(df, field, v)
            case "code":        return self._call(v.attr("fn"), df, field)
            case _:             return df
```

### Stakeholder Review Workflow

CX is the source of truth. Excel is generated from CX for stakeholder review:

```python
# tools/field_map_exporter.py
import cxlib
import pandas as pd

def export_to_excel(cx_path: str, excel_path: str) -> None:
    doc = cxlib.parse_file(cx_path)
    with pd.ExcelWriter(excel_path) as writer:
        _export_fields(writer, doc.find_all("field"))
        _export_merges(writer, doc.find_all("merge"))
        _export_splits(writer, doc.find_all("split"))
        _export_constraints(writer, doc.find_all("constraint"))
        _export_lookups(writer, doc.find_all("lookup_table"))
```

Stakeholders review the Excel output, comment, and return changes. Engineers apply changes to the `.cx` source file. Excel is a projection for review, never edited as source.

For teams where stakeholders must edit directly without engineer involvement, the Excel-as-master approach in the base spec is more appropriate.

### Field Map Validation

A `tools/field_map_validator.py` runs in CI and locally to validate field map structure before commit. It checks:

- File parses as valid CX
- Required attributes present on every element
- All `target_type` and `source_type` values from the legal vocabulary
- All `[transform type=...]` and `[validation type=...]` values are known types
- All `[transform type=lookup table=name]` references exist in `[lookups]`
- All `[fk_ref]` elements have valid `table` and `field` attributes
- All `[transform type=code fn=name]` references exist as methods in the corresponding transformer
- All `[validation type=code fn=name]` references exist as methods in the corresponding transformer

CI rejects any PR that introduces a field map failing validation.

---

## 6. Operational Concerns

### Result Types

Each layer returns a typed result that captures both data and operational metadata.

```python
# shared/results.py

@dataclass(frozen=True)
class TransformResult:
    clean_df: pd.DataFrame
    rejected_count: int = 0
    quarantined_count: int = 0
    flagged_count: int = 0
    rejected_df: pd.DataFrame | None = None
    quarantined_df: pd.DataFrame | None = None

@dataclass(frozen=True)
class LoadResult:
    rows_written: int
    rows_skipped: int
    destination: str
    duration_ms: int

@dataclass(frozen=True)
class PipelineResult:
    pipeline: str
    started_at: datetime
    duration_ms: int
    rows_extracted: int
    rows_transformed: int
    rows_loaded: int
    rejected: int
    quarantined: int
    flagged: int
    success: bool
    error: str | None = None

@dataclass(frozen=True)
class JobResult:
    job: str
    started_at: datetime
    duration_ms: int
    pipeline_results: list[PipelineResult]
    success: bool
```

### Exception Hierarchy

```python
# shared/exceptions.py

class EtlError(Exception):
    """Base for all ETL errors."""

class ConfigError(EtlError):
    """Configuration is missing, invalid, or references missing secrets."""

class ExtractError(EtlError):
    """Extraction failed — source unreachable, auth failed, query error."""

class TransformError(EtlError):
    """Transformation failed in a way that halts the pipeline."""

class LoadError(EtlError):
    """Loading failed — destination unreachable, constraint violation, etc."""

class ValidationError(EtlError):
    """A halt-level validation failed."""

class FieldMapError(EtlError):
    """Field map is malformed or references unknown transforms/validations."""
```

### Logging

Structured JSON logging via Python's `logging` module with a JSON formatter. One log line per significant event, never inside tight loops.

```python
# shared/observability.py
import logging
import json

class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            **getattr(record, "extra_fields", {}),
        }
        return json.dumps(payload)

def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
    return logger
```

### Required Log Fields

Every log line includes:

- `timestamp` — ISO 8601 UTC
- `level` — `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- `job_id` — UUID per job run, propagated through all child operations
- `pipeline` — pipeline name when applicable
- `system` — source or target system when applicable
- `environment` — environment when applicable

Use `logger.info(msg, extra={"extra_fields": {...}})` to attach context.

### Logging by Layer

| Layer | Log at | Level |
|---|---|---|
| Job | Start, end, retry attempts, alerting events | INFO / ERROR |
| Pipeline | Start, end, per-step start/end, row counts | INFO |
| Extractor | First and last row counts, total duration | INFO |
| Internal client | Failed requests, retry attempts, response codes outside 2xx | WARNING / ERROR |
| Transformer | Row count in/out, rejected/quarantined/flagged counts | INFO |
| Loader | Rows written, conflicts encountered | INFO / WARNING |

Never log row-level data at INFO. Row-level diagnostics go to DEBUG only, and only when explicitly enabled.

### Metrics

Pipelines emit metrics at end-of-run. Recommended metrics:

| Metric | Type | Tags |
|---|---|---|
| `etl.pipeline.duration_ms` | gauge | pipeline, success |
| `etl.pipeline.rows_extracted` | counter | pipeline, source_system |
| `etl.pipeline.rows_loaded` | counter | pipeline, target_system |
| `etl.pipeline.rows_rejected` | counter | pipeline, reason |
| `etl.pipeline.rows_quarantined` | counter | pipeline |
| `etl.pipeline.rows_flagged` | counter | pipeline |
| `etl.extractor.duration_ms` | histogram | source_system, method |
| `etl.loader.duration_ms` | histogram | target_system, method |
| `etl.client.request_duration_ms` | histogram | source_system, transport |
| `etl.client.request_failures` | counter | source_system, transport, status |

Metrics are emitted via a pluggable backend — StatsD, Prometheus, OpenTelemetry. The default backend is configurable; production uses whatever the platform team standardizes on.

### Tracing

Each pipeline run creates a trace span. Each call to extractor, transformer, loader is a child span. Use OpenTelemetry conventions where possible.

### Retries

Retries happen at three layers, each with different policies:

| Layer | What it retries | Default policy |
|---|---|---|
| Internal client | Individual HTTP/DB/FTP requests | Exponential backoff, max 3 attempts, retry on 5xx and connection errors |
| Loader | Individual write operations | Exponential backoff, max 3 attempts, retry on transient errors only |
| Job | Whole pipeline runs that fail | No retry by default — rerun manually or via scheduler |

Pipelines do not retry. A pipeline either succeeds or fails atomically. If retry is needed, the job orchestrator triggers a fresh run.

```python
# shared/retry.py
def with_retry(
    max_attempts: int = 3,
    backoff_initial_ms: int = 100,
    backoff_max_ms: int = 30_000,
    retry_on: tuple[type[Exception], ...] = (TransientError,),
):
    """Decorator for retryable operations."""
```

### Idempotency

All loaders must be idempotent — running the same load twice produces the same target state, not duplicate rows. Implementation approaches:

- **Upsert with natural key** — preferred when target has stable PK
- **Insert with deduplication** — for append-only tables, use surrogate IDs derived from source content
- **Replace-by-partition** — for partitioned tables, drop and reload affected partitions

Pipelines that cannot be made idempotent must document this explicitly in their pipeline README.

### Quarantine and Reject Destinations

Rejected and quarantined rows are written to durable destinations, not just logged. Configuration:

```toml
# config/systems/targets/postgres.toml

[environments.prod]
connection_string_ref = "TARGET_DB_URL"
schema = "public"
quarantine_table = "etl_quarantine"      # all quarantined rows from any pipeline
reject_table = "etl_rejects"             # all rejected rows from any pipeline
```

Quarantine and reject tables have a standard schema:

| Column | Type | Description |
|---|---|---|
| `id` | uuid | Surrogate key |
| `pipeline` | text | Pipeline name |
| `target_table` | text | Original target |
| `reason` | text | Why this row was quarantined/rejected |
| `field` | text | Field that failed (if applicable) |
| `row_data` | json | Original row contents |
| `flags` | json | All flags raised on this row |
| `quarantined_at` | timestamp | When |
| `job_id` | uuid | Job run that produced this |

Operators monitor these tables and either fix and replay, or accept the loss.

### Watermarks and Incremental Load

Pipelines that do incremental extraction (e.g. `extract_orders(since=...)`) need watermark state — the latest successfully processed timestamp or sequence ID.

```python
# shared/watermarks.py

@dataclass(frozen=True)
class Watermark:
    pipeline: str
    source_system: str
    domain: str
    last_value: str           # serialized — could be timestamp, ID, etc.
    last_value_type: str      # for deserialization
    updated_at: datetime

class WatermarkStore(ABC):
    @abstractmethod
    def get(self, pipeline: str, source_system: str, domain: str) -> Watermark | None: ...
    @abstractmethod
    def set(self, watermark: Watermark) -> None: ...
```

Watermark stores are pluggable — file-based for dev, Postgres or DynamoDB for prod. Watermarks are advanced **only** after a successful pipeline run, not after extraction. A pipeline that extracts but fails to load does not advance the watermark.

### Alerting

Alerts fire on:

- Job failure
- Pipeline failure
- Rejection rate above threshold (configurable per pipeline)
- Quarantine rate above threshold
- Pipeline duration above threshold
- Watermark falling behind (no successful run within expected window)

Alerts route to whatever the platform team uses — PagerDuty, Slack, email. The job is responsible for emitting alert events; the routing is platform infrastructure.

---

## 7. Pipeline & Job Orchestration

### Pipeline Composition

A pipeline does one cohesive unit of work — one target domain, one logical flow. Pipelines do not call other pipelines.

When a workflow needs multiple pipelines, the **job** orchestrates them, not a meta-pipeline. This keeps pipelines composable and testable in isolation.

```python
class NightlyDataRefreshJob:
    """Runs the full nightly refresh — customers, orders, inventory."""

    def run(self) -> JobResult:
        config = ConfigLoader()
        results = []

        for pipeline_factory in [
            self._customer_pipeline,
            self._order_pipeline,
            self._inventory_pipeline,
        ]:
            try:
                results.append(pipeline_factory(config).run())
            except EtlError as e:
                results.append(PipelineResult.failed(pipeline_factory.__name__, e))
                if self._should_halt_on_failure(pipeline_factory.__name__):
                    break

        return JobResult.from_pipeline_results(self.__class__.__name__, results)
```

### Job Triggers

Jobs are triggered by external infrastructure — cron, Airflow, Prefect, event bus, manual invocation. The job class itself is unaware of how it was triggered. The trigger mechanism passes parameters as constructor args or method args.

| Trigger style | File naming | Example |
|---|---|---|
| Cron / scheduled | `{schedule}_{domain}_job.py` | `nightly_customer_job.py`, `hourly_inventory_job.py` |
| Event-driven | `on_{event}_{domain}_job.py` | `on_file_arrival_invoice_job.py` |
| Manual | `on_demand_{domain}_job.py` | `on_demand_backfill_job.py` |
| Webhook | `webhook_{domain}_job.py` | `webhook_order_event_job.py` |

### Job Dependencies

Jobs that depend on other jobs declare their dependencies in their README, not in code. The actual orchestration of dependencies belongs to the scheduler — Airflow DAG, Prefect flow, etc. The ETL project ships jobs as standalone runnable units.

### Backfill and Replay

Every pipeline supports two modes:

- **Incremental** — uses watermark, processes only new data
- **Backfill** — given an explicit date range, processes regardless of watermark

```python
class CustomerSyncPipeline:
    def run(
        self,
        since: date | None = None,
        until: date | None = None,
        backfill: bool = False,
    ) -> PipelineResult:
        if backfill:
            since = since or self._earliest_available_date()
            # do not advance watermark on completion
        else:
            since = self.watermark_store.get(...).last_value or self._earliest_available_date()

        ...
```

Backfill runs do **not** advance the watermark. They run alongside ongoing incremental jobs without interfering.

---

## 8. Data Flow & Performance

### DataFrame Size Assumption

The default pattern assumes data fits in memory as a single pandas DataFrame. This is appropriate for most ETL workloads up to single-digit millions of rows.

When this assumption breaks down — typical signals are OOM errors, swap thrashing, or extraction times that exceed the job window — pipelines move to chunked or streaming execution.

### Chunked Execution

For data sets larger than memory but fundamentally row-independent, pipelines process in chunks.

```python
class CustomerSyncPipeline:
    CHUNK_SIZE = 50_000

    def run(self, since: date | None = None) -> PipelineResult:
        result = PipelineResult.empty(self.__class__.__name__)
        for chunk in self.extractor.extract_customers_chunked(since, self.CHUNK_SIZE):
            transformed = self.transformer.transform(chunk)
            load_result = self.loader.load(transformed.clean_df, table="customers")
            result = result.merge_chunk(transformed, load_result)
        return result
```

Chunked extraction returns an iterator of DataFrames. The transformer and loader operate per-chunk. Watermarks advance only after the entire run completes.

### Streaming

For very large data sets or low-latency needs, pipelines use a streaming pattern where extractor, transformer, and loader operate on a row stream rather than DataFrames.

Streaming is opt-in per pipeline, not a global setting. Most pipelines do not need it. When streaming is needed, the pipeline declares it and uses streaming variants of base classes.

```python
class StreamingExtractor(BaseExtractor):
    def extract_stream(self, *args, **kwargs) -> Iterator[dict]: ...

class StreamingLoader(BaseLoader):
    def load_stream(self, rows: Iterator[dict], *args, **kwargs) -> LoadResult: ...
```

### Backpressure

When the source produces faster than the destination can absorb, the pipeline must handle backpressure rather than buffering unboundedly.

| Pattern | Mechanism |
|---|---|
| Chunked | Synchronous — next chunk extracted only after previous chunk loaded |
| Streaming | Bounded queue between extractor and loader, blocking writes when full |
| Batched | Loader accumulates a batch and flushes; backpressure via batch flush time |

### Intermediate State

Intermediate DataFrames live in process memory. Disk-based intermediate state is the exception, not the rule, and must be justified in the pipeline README.

When disk-based intermediate state is necessary (e.g. very large joins that exceed memory), use Parquet files in a pipeline-scoped temporary directory that is cleaned up on completion or failure.

---

## 9. Testing

### Test Structure

```
tests/
├── unit/
│   ├── extractors/
│   │   └── test_system_x_extractor.py
│   ├── transformers/
│   │   └── test_customer_transformer.py
│   ├── loaders/
│   │   └── test_postgres_loader.py
│   └── pipelines/
│       └── test_customer_sync_pipeline.py
├── integration/
│   ├── test_system_x_to_postgres.py
│   └── ...
├── fixtures/
│   ├── system_x/
│   │   ├── customers_sample.json
│   │   └── orders_sample.json
│   └── field_maps/
│       └── customers_test.xlsx
└── conftest.py
```

### Unit Test Patterns by Layer

**Internal clients** — mock the underlying transport (requests, sqlalchemy, ftplib). Assert correct construction of requests, queries, and paths.

**Extractors** — inject fake clients. Assert correct method dispatch and DataFrame shape. Do not test transport details here — that's the client's job.

**Transformers** — pure function testing. Construct an input DataFrame, call `transform()`, assert output. Field map is a small in-memory test fixture.

**Loaders** — mock the destination. Assert correct write operations and conflict handling.

**Pipelines** — inject fake extractors, transformers, and loaders. Assert assembly and merge logic. Do not test transformer or loader logic here.

**Jobs** — inject a fake `ConfigLoader`. Assert correct pipeline construction and orchestration logic.

### Integration Test Patterns

Integration tests run against real or near-real dependencies — ephemeral Postgres in Docker, mocked HTTP servers, real test S3 buckets. They run less frequently than unit tests, typically on PR and on main branch builds.

Integration tests validate:

- End-to-end pipeline execution with real systems
- Schema compatibility with real source and target databases
- Retry behavior under simulated failures
- Watermark advancement across multiple runs

### Mock and Fake Patterns

Prefer fakes over mocks. A fake extractor that returns a fixture DataFrame is more readable than a mock with `.return_value` chained calls.

```python
# tests/fixtures/extractors.py

class FakeSystemXExtractor:
    def __init__(self, customers: pd.DataFrame, orders: pd.DataFrame):
        self._customers = customers
        self._orders = orders

    def extract_customers(self) -> pd.DataFrame:
        return self._customers.copy()

    def extract_orders(self, since: date) -> pd.DataFrame:
        return self._orders[self._orders["created_at"] >= since].copy()
```

### Field Map Validation Tests

The `field_map_validator.py` tool runs against every field map in CI. New field maps require accompanying validator tests that exercise:

- A row using each transform listed
- A row using each validation listed
- A row using each `on_failure` behavior
- Lookup tables resolve correctly
- External lookup references resolve

### Coverage Targets

| Layer | Target |
|---|---|
| Internal clients | 80% — transport correctness |
| Extractors | 70% — dispatch and shape |
| Transformers | 90% — business logic, the most important |
| Loaders | 80% — destination correctness |
| Pipelines | 70% — assembly and merge |
| Jobs | 60% — orchestration |

---

## 10. Documentation Requirements

### System README

Every source and target system has a README at `docs/systems/{system_name}.md`:

```markdown
# {System Name}

## Overview
- What is this system? Who owns it?
- What domains does it serve?

## Access
- Connection methods (API, DB, FTP)
- Auth model
- Rate limits or quotas
- Test/sandbox availability

## Schemas
- Schema versions, current state of migration if applicable
- Pointers to authoritative schema docs upstream

## Operational
- SLAs from the upstream team
- Known issues and workarounds
- Escalation contacts

## Pipelines
- Which pipelines extract from / load to this system
```

### Pipeline README

Every pipeline has a README at `docs/pipelines/{pipeline_name}.md`:

```markdown
# {Pipeline Name}

## Purpose
What this pipeline does in one paragraph.

## Inputs
- Source systems and what is extracted from each
- Schedule or trigger

## Outputs
- Target systems and what is written
- Idempotency: yes/no, justification if no

## Watermarks
- What field tracks incremental progress
- Where watermarks are stored

## Dependencies
- Other pipelines that must run before this one
- External systems that must be available

## Failure Modes
- Known failure modes and recovery procedures
- Backfill procedure

## Owners
- Primary owner, escalation
```

### Architecture Decision Records

Significant architectural decisions go in `docs/adr/`. Format:

```markdown
# ADR-NNNN: {Title}

Date: YYYY-MM-DD
Status: proposed | accepted | superseded by ADR-MMMM

## Context
What problem are we solving? What constraints apply?

## Decision
What did we decide?

## Consequences
What follows from this decision — both positive and negative.

## Alternatives Considered
What else did we look at and why didn't we choose them?
```

ADRs are immutable once accepted. Superseding an ADR creates a new one, never edits the old.

---

## 11. Decisions Made

This section captures decisions made by this spec where reasonable alternatives exist, so future readers can understand the reasoning rather than re-litigating each one.

### Format-Level Decisions (Specific to CX Edition)

| Area | Decision | Alternative considered |
|---|---|---|
| Config format | CX | TOML (the base spec choice — viable when CX tooling unavailable) |
| Field map format | CX | Excel (the base spec choice — better when stakeholders edit directly) |

### CX vs TOML for Configuration

| Concern | TOML | CX |
|---|---|---|
| Type safety | Strict | Strict — same auto-typing rules |
| Comments | Yes | Yes |
| Indentation sensitivity | No | No |
| Programmatic access | Manual key lookup | Document API: `at()`, `attr()`, `select_all()` |
| Query by attribute | No | CXPath: `//environment[@name=prod]` |
| Hierarchical structure | Flat with dotted keys | Native nesting |
| Standard library | `tomllib` (Python 3.11+) | Requires cxlib |
| Ecosystem maturity | Established | Newer — adoption risk on some projects |

### CX vs Excel for Field Maps

The structural argument is the primary reason for CX. A field map is fundamentally hierarchical:
- One transform with parameters
- Multiple validations, each with its own pattern, bounds, and failure behavior
- FK references and constraints
- Lineage across schema versions
- Free-form documentation

Excel forces a choice between many sparse columns, encoded strings, or splitting across sheets. CX holds the structure natively.

| Concern | Excel as master | CX as master |
|---|---|---|
| Data structure | Flat — hierarchy requires encoding | Native hierarchy — nested elements |
| Multiple validations per field | Encoded string or extra rows with join key | Natural — multiple `[validation]` children |
| Transform parameters | Encoded string parsed at runtime | Typed attributes on `[transform]` child |
| Lineage and documentation | Truncated cell or separate sheet | Block content, unlimited |
| Lookup tables | Separate sheet with join key | `[lookup_table]` nested directly |
| Git diff | Binary, no meaningful diff | Text, line-level PR-reviewable diffs |
| Delimiter ambiguity | None (cells are values) | None (attributes are values) |
| Runtime access | pandas read_excel → DataFrame | CX Document API + CXPath |
| Authoring at scale | Excel filters, freeze panes, autocomplete | Text editor with no structured authoring support |
| Collaborative editing | Excel/SharePoint, stakeholders already know it | Text editor or export/reimport roundtrip |
| Stakeholder review | Direct — open and read | Requires `field_map_exporter.py` → Excel |
| Error feedback on edit | Excel data validation rules at entry | Surfaces at parse or validator run |
| Tooling dependency | None beyond Excel | Requires cxlib + working exporter |
| Sync risk | None — one source | CX and exported Excel can diverge if process breaks |
| Ownership | Works for analyst-owned maps | Better for engineer-owned maps |

#### When CX is the right choice

- Engineers own or co-own field maps day to day
- Multiple validations, complex transforms, or lineage tracking are common
- Git audit trail and PR review of field map changes matter to the team
- The project has committed to CX across config and tooling
- The exporter tool is built, tested, and maintained

#### When Excel-as-master is the right choice

- Non-technical stakeholders own field maps day to day
- Field maps are predominantly simple renames and casts — structural richness isn't needed
- Stakeholders must be able to edit directly without engineer involvement
- CX tooling is not yet stable for the project

### Decisions Shared with the Base Spec

| Area | Decision | Alternative considered |
|---|---|---|
| Field maps organized by | Target domain | Source system (rejected — target defines scope) |
| Config files organized by | One file per system, environments inside | One file per system × environment (rejected — file count multiplies, hard to compare environments) |
| Schema versioning | Opt-in per system | Universal (rejected — most systems don't need it) |
| Pipeline composition | Jobs orchestrate, pipelines are leaf | Meta-pipelines (rejected — couples pipelines to each other) |
| Retries | At client and loader, not pipeline | Pipeline-level retries (rejected — pipelines should be atomic) |
| Watermark advancement | After successful load only | After extraction (rejected — would lose data on load failure) |
| Quarantine destination | Standard tables in target system | Side-channel storage (rejected — operators need same access) |
| Idempotency requirement | Required, exceptions documented | Optional (rejected — replay is essential operationally) |
| Default execution model | In-memory DataFrame | Streaming (rejected — overkill for most workloads) |
| Logging format | Structured JSON | Plain text (rejected — operability at scale) |
| Test approach | Fakes preferred over mocks | Mocks (acceptable, but fakes read better) |
| Backfill | Does not advance watermark | Does advance (rejected — would skip subsequent incremental runs) |

---

## Summary: The One-Line Rule Per Layer

| Layer | Rule |
|---|---|
| Internal client | Own the transport — endpoints, SQL, paths, auth, transport retries |
| Extractor | Expose data by name, hide how it's fetched |
| Transformer | Pure logic — DataFrame in, DataFrame out, no I/O, field-map driven |
| Loader | Idempotent writes to one destination, own the format details |
| Pipeline | Assemble and run atomically — business params only, owns merge logic |
| Job | Resolve config, inject into pipelines, orchestrate, alert |
| Config (.cx) | One file per system, environments nested, secrets by reference only |
| Field maps (.cx) | Target-domain organized, hierarchical structure, CX is source of truth |
