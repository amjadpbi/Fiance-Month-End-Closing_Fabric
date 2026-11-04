# Fabric Pipeline Definitions

**Retrieved:** 2026-10-31  
**Mode:** Read-only. Neither pipeline nor any notebook was executed; no Fabric item or data was modified.

## 1. Authentication and retrieval method

The existing signed-in Azure CLI session was used to request an access token for the Fabric API audience (`https://api.fabric.microsoft.com`). The token was used in memory only; it was not printed, saved, or included in this report.

The decoded token claims showed the Fabric audience and delegated scope `user_impersonation`. Microsoft's `dataPipeline` API specification for `Items_GetDataPipelineDefinition` states that the caller must have **read and write permissions for the data pipeline** and lists delegated scopes `DataPipeline.ReadWrite.All` or `Item.ReadWrite.All`. The token did not expose either granular scope name, but successful requests below demonstrate that the current authenticated identity had effective permission for this operation on both items. No permission failure was observed.

The exact official API operation called for each pipeline was:

`POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/dataPipelines/{dataPipelineId}/getDefinition`

The response was HTTP 200 for both requests. Each response contained two `InlineBase64` definition parts: `pipeline-content.json` and `.platform`. Both parts were Base64-decoded; the JSON in each part parsed successfully. No 202 asynchronous response or polling was needed.

## 2. Pipeline identity and retrieval status

The workspace's pipeline list and item metadata were checked against the IDs used in the definition requests. The returned `.platform` metadata also identified each definition as a `DataPipeline` with the expected display name.

| Pipeline | Item ID | Workspace ID | API status | Definition parts |
|---|---|---|---:|---|
| `PL_Elarwick_Gold_To_Warehouse` | `e98584ef-c334-48e3-a7d9-925613360d8a` | `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c` | 200 | `pipeline-content.json` (18,998 decoded bytes), `.platform` (319 bytes) |
| `PL_Elarwick_MonthEnd_Close` | `56d419c8-e1ca-4f47-95bd-9b9493abe0e3` | `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c` | 200 | `pipeline-content.json` (4,517 decoded bytes), `.platform` (316 bytes) |

Both `pipeline-content.json` parts contained valid JSON and actual activity configuration, not just item metadata. The activity counts were seven and four, respectively.

## 3. `PL_Elarwick_Gold_To_Warehouse`

### Activity inventory and execution order

All seven activities are `Copy` activities. They form one sequential chain: each activity after the first depends on the immediately preceding activity succeeding.

| Order | Activity | Source Lakehouse table | Destination Warehouse table | Dependency |
|---:|---|---|---|---|
| 1 | `Copy FactReconciliationResults` | `dbo.gold_reconciliationresults` | `dbo.FactReconciliationResults` | None |
| 2 | `Copy FactReconciliationExceptions` | `dbo.gold_reconciliationexceptions` | `dbo.FactReconciliationExceptions` | Activity 1 — `Succeeded` |
| 3 | `Copy FactReconciliationSummary` | `dbo.gold_reconciliationsummary` | `dbo.FactReconciliationSummary` | Activity 2 — `Succeeded` |
| 4 | `Copy DimAccountMapping` | `dbo.dim_accountmapping` | `dbo.DimAccountMapping` | Activity 3 — `Succeeded` |
| 5 | `Copy DimChartOfAccounts` | `dbo.dim_chartofaccounts` | `dbo.DimChartOfAccounts` | Activity 4 — `Succeeded` |
| 6 | `Copy FactReconciliationAllocationReview` | `dbo.gold_reconciliationallocationreview` | `dbo.FactReconciliationAllocationReview` | Activity 5 — `Succeeded` |
| 7 | `Copy FactReconciliationAllocations` | `dbo.gold_reconciliationallocations` | `dbo.FactReconciliationAllocations` | Activity 6 — `Succeeded` |

Every source uses the `LH_Elarwick_Reconciliation` Lakehouse linked service in workspace `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c`, Lakehouse item `1836fa4b-2f43-4a48-b8d6-de7bd7d9e935`, under `dbo`.

Every sink uses the `WH_Elarwick_Reconciliation` Warehouse linked service in the same workspace, Warehouse item `22a20472-caf8-4bec-affa-ae5d2c788748`. The configured endpoint is `kxme24s4ar5excpmug6oeu3a5a-2upkngedxxhebght4tvazxeofq.datawarehouse.fabric.microsoft.com`.

### Sink and mapping configuration

The seven Copy activities use the same sink and translator settings:

- Sink type: `DataWarehouseSink`.
- `writeBehavior`: `Insert`.
- `tableOption`: `autoCreate`.
- `allowCopyCommand`: `true`; `copyCommandSettings` is empty.
- `enableStaging`: `true`.
- Translator: `TabularTranslator`; `typeConversion`: `true`.
- Type conversion settings: `allowDataTruncation: true`; `treatBooleanAsNumber: false`.
- No explicit column mappings are present in the serialized translator. Source and sink dataset `schema` arrays are empty. Therefore, the definition does **not** document a column-by-column mapping; the runtime's implicit/default mapping behavior is not established by this JSON.
- No transformation steps are configured in these Copy activities.

The configured insert behavior agrees with the project history that rerunning the earlier append-based load created duplicate rows. The definition has no visible upsert, merge, deduplication, or idempotency setting.

### Retry, timeout, failure, and rerun behavior

Each activity has the same policy:

- Timeout: `0.12:00:00` (12 hours).
- Retry count: `0`.
- Retry interval: `30` seconds (configured, but no retries are enabled when retry count is zero).
- `secureInput` and `secureOutput`: `false`.

Only success dependencies are configured. There are no explicit failure handlers, cleanup activities, compensating actions, or failure branches in the definition. Since the chain is sequential, a failed activity prevents later activities from satisfying their `Succeeded` dependency; earlier completed writes are not rolled back by any configured pipeline activity. A rerun starts the activity chain again, and the `Insert` sinks provide no definition-level protection against repeating prior writes.

### Parameters and dynamic expressions

The decoded root `properties` contains only `activities`. No pipeline parameters, variables, or dynamic expressions were present in the retrieved definition.

## 4. `PL_Elarwick_MonthEnd_Close`

### Activity inventory and execution order

The four activities form one sequential success-dependent chain:

| Order | Activity | Type | Configuration | Dependency |
|---:|---|---|---|---|
| 1 | `Run_Bronze_Ingestion` | `TridentNotebook` | Notebook `bbe940fc-a2c4-4ff6-9390-55e94035a151`; workspace `98a61ed5-bd83-40ce-98f3-e4ea0cdc8e2c` | None |
| 2 | `Run_Silver_Validation` | `TridentNotebook` | Notebook `e8d17ad4-8365-4db7-a3d6-49f2d5e2fcde`; same workspace | Activity 1 — `Succeeded` |
| 3 | `Run_Journal_Controls` | `TridentNotebook` | Notebook `fc72573b-d29d-4222-a93b-389806537667`; same workspace | Activity 2 — `Succeeded` |
| 4 | `Copy_Gold_ReconciliationResults` | `Copy` | `dbo.gold_reconciliationresults` to `dbo.FactReconciliationResults` | Activity 3 — `Succeeded` |

The final activity uses the same Lakehouse and Warehouse item IDs, linked-service names, sink settings, staging, and translator settings described above. Its sink is `Insert` with `tableOption: autoCreate`; no explicit column mappings are serialized.

Each of these four activities has timeout `0.12:00:00`, retry count `0`, retry interval `30` seconds, `secureInput: false`, and `secureOutput: false`. There are no explicit failure branches or cleanup steps. The pipeline definition has no parameters, variables, or dynamic expressions.

### Relationship to the Gold-to-Warehouse pipeline

The retrieved definition contains **no execute-pipeline activity** and does not invoke `PL_Elarwick_Gold_To_Warehouse`. Instead, this pipeline includes one direct Copy activity for reconciliation results only. The definition therefore does not support treating `PL_Elarwick_MonthEnd_Close` as an orchestrator that runs the seven-activity Gold-to-Warehouse pipeline.

## 5. Verified configuration excerpts

The following excerpts are from the decoded pipeline definitions. They establish the activity type, success dependency, timeout/retry policy, and insert sink behavior:

```json
{
  "name": "Copy FactReconciliationExceptions",
  "type": "Copy",
  "dependsOn": [
    {
      "activity": "Copy FactReconciliationResults",
      "dependencyConditions": ["Succeeded"]
    }
  ],
  "policy": {
    "timeout": "0.12:00:00",
    "retry": 0,
    "retryIntervalInSeconds": 30
  }
}
```

```json
{
  "type": "DataWarehouseSink",
  "allowCopyCommand": true,
  "copyCommandSettings": {},
  "writeBehavior": "Insert",
  "tableOption": "autoCreate"
}
```

## 6. Remaining unknowns and evidence boundaries

**Verified from the API definition:** item identities, activity names/types, configured source and sink item/table references, dependency conditions, serialized sink/translator settings, and activity policy settings.

**Not established by the definitions:**

- Explicit column-to-column mappings; none are serialized. Whether default name-based or other runtime mapping applies was not verified.
- Notebook code behavior, side effects, or the exact tables each notebook writes. Notebook IDs are recorded above; notebooks were not opened or executed for this task.
- Runtime outcomes such as whether a failure actually leaves partial data, or whether the configured `autoCreate` option is exercised for existing tables.
- Any behavior implemented outside these pipeline definitions.

No pipeline, notebook, Warehouse object, Lakehouse object, semantic model, report, or data was changed or executed during retrieval.
