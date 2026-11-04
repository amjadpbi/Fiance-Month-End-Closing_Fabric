# Fabric Execution History and Orchestration Audit

**Retrieved:** 2026-10-31  
**Mode:** Read-only. No notebook or pipeline was executed; no Fabric item or data was modified.

## 1. Executive Findings

- **Verified:** Fabric's authenticated item job-history API returned execution records for the specified notebook and pipeline IDs. The job-list and generic job-detail requests used in this audit returned HTTP 200.
- **Observed:** The October 23 `NB_01_Ingest_Bronze` file outcomes fall within two `RunNotebookInteractive` sessions. The four original successful file outcomes fall within run `c8bcb4d1-153c-4a99-a1b2-75e1aa7bf630` (16:10:41–16:57:06 UTC). The three e32 outcome rounds and three repeated batch summaries fall within run `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71` (17:44:16–19:05:42 UTC). Neither run record includes the control-table `BatchID`.
- **Inferred, not directly linked:** Run `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71` is the strongest candidate for the four function-signature failures and subsequent skips: its start is within seconds of e32's `StartedAt`, and all recorded e32 events fall within the run interval. No execution ID is stored with those control records to prove the link.
- **Verified:** The failed file records say `file_version_already_loaded() takes 1 positional argument but 3 were given`. The current deployed notebook defines and calls that helper with three arguments (definition at source lines 165–167; call at 262–264). The history response has no source version or historical source hash. It cannot establish whether the executed code was older, stale in the interactive kernel, or otherwise different.
- **Observed:** The API reports the October 23 interactive NB_01 run as `Completed` with no job-level failure reason. This is consistent with the currently deployed per-file exception handler recording failures without failing the overall notebook execution, but does not prove which source version ran.
- **Verified:** Six `PL_Elarwick_MonthEnd_Close` executions were returned for October 27: one `Completed` and five `Failed`. Each failure names `Run_Silver_Validation`; its nested failure includes an NB_02 run ID and a Spark capacity `HTTP 430 TooManyRequestsForCapacity` error. This is a separate, verified October 27 orchestration failure and does not explain October 23 control-table anomalies.
- **Inferred:** The repeated e32 batch ID and identical `StartedAt` are consistent with an interactive session re-running processing/summary cells while retaining the generated `BATCH_ID` variable. The current code permits repeated append writes for the same retained ID, but execution/cell logs are unavailable to establish that this happened.
- **Unknown:** The successful `34a5...` file batch has no `control_batches` row. Current code writes the file outcomes before the final batch summary. The available records cannot distinguish an unrun final cell, a failed summary append, or different historical code.

## 2. Retrieved Execution Records

### API method and limits

The existing signed-in Azure CLI session was used to obtain a Fabric API access token in memory only. No credential or token was printed or saved.

- **Verified:** The item-history request was `GET https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/jobs/instances`; individual records were checked with `GET .../jobs/instances/{jobInstanceId}`. Both endpoints returned HTTP 200 for the requests completed here.
- **Verified:** The official API specification says item job history is limited to 100 recently completed entities for most item types. This is an execution-history snapshot, not evidence that older history is retained indefinitely.
- **Verified limitation:** The notebook-specific beta detail endpoint, `GET /v1/workspaces/{workspaceId}/notebooks/{notebookId}/jobs/execute/instances/{jobInstanceId}?beta=true`, returned HTTP 404 for the October 23 NB_01 run. The generic item endpoint did return HTTP 200, but only the metadata fields listed below.
- **Verified:** Job records exposed `id`, `itemId`, `jobType`, `invokeType`, `status`, `failureReason`, `rootActivityId`, `startTimeUtc`, and `endTimeUtc`. They did not expose notebook parameters, cell-by-cell execution output, notebook source version/hash, or an explicit parent pipeline run ID.
- **Verified:** The item-history responses contained 10 instances each for NB_01, NB_02, and NB_03; 6 for Month-End; and 8 for Gold-to-Warehouse. The tables below include all returned runs in the requested windows. The history API's recent-instance limit means these counts should not be treated as an unlimited archive.
- **Verified:** Current NB_01 definition retrieval used `POST /v1/workspaces/{workspaceId}/notebooks/{notebookId}/getDefinition`, which returned HTTP 202. The operation completed with HTTP 200 and `Succeeded`; `GET {operationUrl}/result` returned HTTP 200 and the current `notebook-content.py` and `.platform` parts. This is current source only, not a historical version.

### NB_01 October 23 sessions and October 27 child runs

Fabric `startTimeUtc` / `endTimeUtc` values are UTC. Control-table timestamps are returned without a timezone; the current notebook writes UTC-naive values, so the comparisons below use UTC, but historical timezone handling is not independently captured in the run records. `rootActivityId` is the value returned by Fabric; it is not the job `id`.

| Date/time (start–end) | NB_01 job ID | Job type / status | `rootActivityId` | Relation to control records |
|---|---|---|---|---|
| Oct 23 16:10:41–16:57:06 | `c8bcb4d1-153c-4a99-a1b2-75e1aa7bf630` | `RunNotebookInteractive` / `Completed` | `0d83f38d-770f-4277-82b2-68c782c3a307` | **Observed:** The four `SUCCEEDED` file outcomes were recorded around 16:36–16:36:50 during this interval. |
| Oct 23 17:09:41–17:35:42 | `99fad09c-e92d-459b-bb08-e3751ca226db` | `RunNotebookInteractive` / `Completed` | `34c2b770-c959-4498-a2d8-cf0108b8537c` | No matching control outcome round was identified in the retrieved records. |
| Oct 23 17:44:16–19:05:42 | `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71` | `RunNotebookInteractive` / `Completed` | `b7e9db19-59c5-4381-9728-018667960bc6` | **Observed:** e32 `StartedAt` was 17:44:26; its file outcomes at 18:06, 18:25, and 18:59 and batch summaries through 19:00:57 fall within this run. |
| Oct 27 08:15:23–08:16:30 | `7faaf61d-43ed-47c4-94d3-e6a93f1621ed` | `PipelineRunNotebook` / `Completed` | `a346b959-cca9-4c4b-807d-d5e44de95969` | **Observed:** Time/type are consistent with the 08:14 Month-End run's Bronze activity; no explicit parent ID in this NB_01 record. |
| Oct 27 08:32:55–08:34:14 | `3f81afdf-d7df-4389-a1d6-a9e5d599aa44` | `PipelineRunNotebook` / `Completed` | `42c95608-d0cc-4f41-b3e7-d06d4fe403c1` | **Observed:** Time/type are consistent with the 08:32 Month-End run's Bronze activity. |
| Oct 27 09:05:12–09:06:13 | `5cf8d9d0-1395-4422-a996-f388648a94cd` | `PipelineRunNotebook` / `Completed` | `c30369e4-fe69-45b7-898a-db0521aa432b` | **Observed:** Time/type are consistent with the 09:04 Month-End run's Bronze activity. |
| Oct 27 09:12:07–09:13:19 | `c925e3e5-14ce-4ea5-b48e-7f948235db1c` | `PipelineRunNotebook` / `Completed` | `d46cf471-fabc-471e-96ae-d985854ae028` | **Observed:** Time/type are consistent with the 09:11 Month-End run's Bronze activity. |
| Oct 27 11:00:20–11:01:21 | `abdbfab1-00d8-4112-8c9e-04690dec217f` | `PipelineRunNotebook` / `Completed` | `523e777c-2058-41d4-8559-ca8751e35be8` | **Observed:** Time/type are consistent with the 10:59 Month-End run's Bronze activity. |
| Oct 27 13:19:46–13:20:55 | `297773d5-cac3-49d6-af4a-2eb388d79241` | `PipelineRunNotebook` / `Completed` | `3939a011-f4a5-4cff-a1f4-9b96a006d94c` | **Observed:** Time/type are consistent with the 13:19 Month-End run's Bronze activity. |

### October 27 Month-End and related notebook records

| Parent Month-End run | Parent interval (UTC) | Parent status | Parent `rootActivityId` | Failed activity / child NB_02 job ID | Child interval (UTC) | Child `rootActivityId` | Fabric request ID |
|---|---|---|---|---|---|---|---|
| `68c9e76d-31a8-4f5e-8936-02e0609ea99f` | 08:14:56–08:17:03 | Failed | `b134abac-e0ae-4847-a8eb-5c7f73cf61ed` | `Run_Silver_Validation` / `5d5a60a4-3a16-4a5a-8336-0106d74b6753` | 08:16:43–08:16:45 | `416186f1-4805-4b60-bbfd-7813e0cf077b` | `d4ea4199-e03a-4e88-b6d7-ec71d1502934` |
| `715152ae-5463-4756-afe6-e151ba263670` | 08:32:37–08:38:09 | Completed | `e9cd0a24-9a1a-4593-b98f-9305c8a3007a` | `Run_Silver_Validation` / `444a6450-10ab-44aa-a1fe-cb274e9cbd26` (Completed) | 08:34:30–08:35:51 | `80c6990d-7c68-4ac2-a578-f0ccc18ad974` | — |
| `1f8a13d1-d93b-4f25-bc14-e92e3f636259` | 09:04:52–09:06:57 | Failed | `d6912e2a-83ad-4403-bea1-bcb1e001d34e` | `Run_Silver_Validation` / `c0f6e6f8-7c30-4000-95d5-36e6fea275d4` | 09:06:35–09:06:36 | `822a9fe3-125e-4cec-8f78-6badfc6f53ff` | `23b71e83-17f6-4fb6-b849-bdd2205ba638` |
| `d1ed2253-ecd5-4af7-bf9d-1f10556991b9` | 09:11:48–09:13:44 | Failed | `c3f3d304-e771-4ccb-ad16-19f3c8137a91` | `Run_Silver_Validation` / `fd79e442-9b03-4286-bef0-e3cdd2cdf2c2` | 09:13:26–09:13:27 | `8863133d-9471-4ea2-8e77-a6fc19bc9675` | `0f9ecf20-4c11-4d7c-9ea3-ceccdff49668` |
| `458e5ce6-f7e0-4346-918f-dfea45781289` | 10:59:54–11:01:50 | Failed | `ff0a8215-7fb3-49b3-bff4-b9693bf659f5` | `Run_Silver_Validation` / `c7f95b61-7988-48be-8da8-a66fde57d0ad` | 11:01:43–11:01:45 | `f350d070-ec91-437e-bbc5-0743aead9ae8` | `2af039c3-b313-4260-8b47-98cf85897e6a` |
| `a424463a-edfa-4999-bbfd-cbfb383f0e7b` | 13:19:24–13:21:25 | Failed | `de94085c-fdc3-452d-9e11-d35d6bbdeeb5` | `Run_Silver_Validation` / `f003d07b-a0b9-43cf-997f-beb7e1b4cd71` | 13:21:06–13:21:08 | `742aaf82-9f9e-46aa-a3bd-c123739ccbe6` | `3782d948-9da0-44ae-b12b-9a0f1f071b57` |

- **Verified:** In each failed parent record, the failure message names `Run_Silver_Validation` and embeds the child notebook `runId` shown above. The same IDs appear as failed NB_02 `PipelineRunNotebook` instances. The five NB_02 runs were `Failed`; each reports `HTTP Response code 430` and `TooManyRequestsForCapacity` while creating a Livy session. Their `failureReason.requestId` was `bb938f7b-6f01-4051-8bdf-e0e194f0455e` in the returned records, and `isRetriable=false`.
- **Verified:** The parent pipeline failure records use error code `2451`; the child notebook failure is specifically a Spark capacity/concurrency limit, not the October 23 Python function-signature error.
- **Observed / inferred:** The completed 08:32 parent encloses a successful NB_01 run (08:32:55–08:34:14), NB_02 run `444a6450-10ab-44aa-a1fe-cb274e9cbd26` (08:34:30–08:35:51), and NB_03 run `22e5bbae-a5f6-45b9-8bde-dd9645541fba` (08:36:06–08:38:06). The sequential intervals and `PipelineRunNotebook` types strongly match the parent pipeline definition, but those successful notebook records do not contain the parent pipeline ID; the association is therefore inferred from timing/type, not a direct parent pointer.
- **Observed:** NB_02 also has a `RunNotebookInteractive` execution `f09ecedc-3b17-4f08-8eb4-0410d2c64795`, Completed 11:04:53–11:07:29 UTC, with `rootActivityId=2dda67c0-c2ed-4339-9747-2e3a044fdc76`, after the 10:59 parent failure. Its job record does not identify a parent pipeline.
- **Observed:** NB_03 has one run in the requested windows: `22e5bbae-a5f6-45b9-8bde-dd9645541fba`, `PipelineRunNotebook` / `Completed`, 08:36:06–08:38:06 UTC, `rootActivityId=f11016a8-e5a1-4eec-8b13-5c7ae9437da4`. No Month-End parent run was returned for October 23. The Gold-to-Warehouse pipeline history returned no instance within either requested window. Its available history included an October 27 15:11 run, outside the requested window, which failed on `DeltaNotSupportedDataType` for `BankTransactionIDs` (array); it is not evidence about the October 23 Bronze events.

## 3. October 23 Function-Signature Error

- **Verified from control records:** Four file-level outcomes in batch `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` are `FAILED`, each with the exact message `file_version_already_loaded() takes 1 positional argument but 3 were given`. Each has `SourceRowCount=0`.
- **Verified from current deployed source:** `file_version_already_loaded` is defined with `file_hash`, `filename`, and `target_table` (source lines 165–167). It is called with those three arguments at lines 262–264. The current definition therefore does not produce the historical one-argument signature error when that same definition is the callable bound at execution.
- **Observed:** The most likely associated job record is the manually invoked interactive NB_01 job `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71`, which was `Completed` from 17:44:16.5111069 to 19:05:42.5313109 UTC. e32 `StartedAt` was 17:44:26.140040. The four failures were logged from 18:06:37.638 to 18:06:53.523; the first skip round from 18:25:38.348 to 18:26:00.514; and the later skip round from 18:59:33.221 to 18:59:48.007. The three summary rows were completed at 18:34:27.718311, 19:00:33.047916, and 19:00:57.139915. All events fall within that job interval.
- **Inferred:** The error establishes that the callable bound at the failed invocation did not match the currently retrieved three-argument definition. A stale function binding in an interactive kernel, an older notebook source/cell version, or another execution context could explain it. The history record does not identify the executed source revision or cell, so these explanations cannot be distinguished.
- **Unknown:** The API does not provide historical notebook source/version references, cell execution logs, cell outputs, parameters, or a code hash for this run. It cannot establish that the deployed notebook was changed after the error, or whether the runtime used a stale function definition versus another invocation/source.
- **Observed:** The top-level NB_01 run reports `Completed` and `failureReason=null`, despite the four file-level failures. **Inferred:** This is consistent with current code catching per-file exceptions and persisting `FAILED` outcomes rather than rethrowing them as a notebook-level failure. Since the source version used on October 23 is unknown, the current handler is not proof of the historical control flow.

## 4. BatchID Reuse and Missing Summary

### Successful BatchID with no summary

- **Verified from existing control audit:** `34a5af9d-c60f-4d1d-9c83-0899a54ebbe6` has four file-level `SUCCEEDED` records with row counts 20, 40, 10, and 15. Those versions exist in Bronze with the same counts. There is no `control_batches` row for this ID.
- **Observed:** The successful outcomes fall within NB_01 interactive job `c8bcb4d1-153c-4a99-a1b2-75e1aa7bf630` (16:10:41–16:57:06 UTC), which reports Completed. The control rows contain no job ID, so this is a time-based association.
- **Verified from code:** The current notebook writes each file outcome during its file-processing loop, then appends the batch-summary record after the loop. The per-file outcome can therefore be persisted before the summary.
- **Unknown:** Neither execution history nor control rows establish whether the summary cell was not run, its append failed, or historical code took another path. A Completed interactive job does not establish that every notebook cell or final append ran successfully.

### Reused e32 BatchID

- **Observed:** `e32be7c5-cf21-47ba-a982-e5d8ed477bf4` is present in 12 file outcomes (four `FAILED` around 18:06, four `SKIPPED` around 18:25, four `SKIPPED` around 18:59) and three `control_batches` records. All three summaries have the same `StartedAt=2026-10-23 17:44:26.140040` and different `CompletedAt` values: 18:34:27.718311, 19:00:33.047916, and 19:00:57.139915 UTC. Each summary says `COMPLETED`, 4 expected, 0 succeeded, 4 skipped, 0 failed, and 0 rows ingested.
- **Observed:** These records fall inside the same NB_01 `RunNotebookInteractive` job interval. The available job record identifies one interactive session, not three separate NB_01 job instances. It does not expose cell execution IDs or associate any control append with a run ID.
- **Verified from current source:** `BATCH_ID = str(uuid.uuid4())` and `BATCH_STARTED_AT = datetime.now(timezone.utc).replace(tzinfo=None)` are assigned together at source lines 48–49. File outcomes include that `BATCH_ID`. The final batch summary is appended at lines 415–432 after counts are calculated; the current code does not deduplicate or upsert a summary by `BatchID`.
- **Inferred:** The repeated ID and unchanged start time are consistent with re-executing file-processing and/or summary cells in one interactive session while retaining the in-memory `BATCH_ID` and `BATCH_STARTED_AT`. Re-executing the final append block can create repeated summary rows because it appends. This is a plausible explanation, not a verified historical event.
- **Unknown:** The records cannot distinguish repeated cell execution from another writer replaying rows, historical implementation behavior, or another logging path. They do not prove that the three summaries represent three separate notebook job executions; the retrieved NB_01 job list shows only one matching interactive job interval.

## 5. Control-Record Write Sequence

The following describes the current retrieved deployed NB_01 source, not a verified October 23 source snapshot:

1. **Batch identity:** Source lines 48–49 generate one UUID and one UTC-naive start timestamp when the setup code executes.
2. **Per-file attempt:** For each source file, the notebook initializes the file outcome as `FAILED`, then computes/checks the file version and, when needed, writes Bronze rows carrying the current batch ID.
3. **Per-file exception and logging:** The exception handler at lines 331–335 records the exception text and leaves the file outcome `FAILED`. The `finally` block at lines 337–359 appends a row to `Control_SourceFiles` and appends the outcome to the in-memory `file_results`.
4. **Batch result:** After the file loop, lines 386–410 calculate success/skipped/failed counts and status. Lines 415–432 create and append one `Control_Batches` row. Existing project investigation of the deployed code established that the control Delta writes use append mode.
5. **No outer finalizer:** There is no separate outer `finally` that guarantees a summary write if execution exits before reaching the post-loop summary section.

Consequences and evidence limits:

- **Verified code-level possibility:** If appending a file outcome from the per-file `finally` raises, that exception can abort execution before the later batch summary append. The existing code does not provide a separate durable recovery path for that case.
- **Verified code-level possibility:** If the summary section is re-executed with the existing in-memory batch variables, it appends another summary row for the same ID; there is no unique key or deduplication in the current write sequence.
- **Verified code-level limitation:** The current history API does not expose whether individual cells ran, whether a control append failed, or which in-memory variable values were present when a cell was run.
- **Unknown historical cause:** These code paths make both missing summaries and repeated same-ID summaries possible, but do not prove which path produced the October 23 records.

## 6. Verified Findings vs Inferences vs Unknowns

| Classification | Finding |
|---|---|
| **Verified** | The October 23 function-signature error is present in all four failed file outcomes, and all four file versions also have full Bronze rows under the earlier successful load. |
| **Verified** | Current deployed NB_01 defines and invokes `file_version_already_loaded` with three arguments. The history API has no historical source revision/hash for the October 23 run. |
| **Observed** | The successful file outcomes align in time with NB_01 interactive run `c8bcb4d1-153c-4a99-a1b2-75e1aa7bf630`; e32 outcomes and summaries align with interactive run `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71`. |
| **Inferred** | Those two interactive runs are the likely execution contexts for the success batch and e32 retry rounds, respectively. Neither link is explicit because the control tables omit job IDs. |
| **Verified** | The e32 batch ID/start timestamp is repeated across three summary rows and twelve file outcomes; the successful `34a5...` batch has file outcomes but no summary. |
| **Inferred** | Re-execution of notebook cells in an interactive session could reuse in-memory batch variables and append repeated summaries. |
| **Unknown** | Whether the October 23 signature error came from changed historical source, a stale interactive function definition, or a different execution path. |
| **Unknown** | Whether the `34a5...` summary cell was never run, the summary append failed, or another historical path explains the absent summary. |
| **Verified** | Five October 27 Month-End runs failed at `Run_Silver_Validation`; each parent failure includes the matching NB_02 failed run ID and a Spark capacity `HTTP 430` error. |
| **Verified / inferred** | The October 27 capacity failures are established; the completed 08:32 pipeline's three successful notebook runs align by type and timing, but their job records lack explicit parent IDs. |

Overall, the October 23 control-table inconsistencies are most consistent with separately persisted notebook cell outcomes and a repeated interactive-session execution context. However, the available evidence does not establish whether source-version drift, stale kernel state, a skipped/failing summary append, or another process caused each inconsistency. The verified October 27 orchestration failures have a distinct capacity-limit cause at Silver.

## 7. Remaining Evidence Gaps

1. No historical NB_01 source snapshot, Git commit/version ID, or source checksum is attached to any returned run.
2. No cell-level execution records or outputs are available for the October 23 interactive runs, including the exact cell that emitted the signature error.
3. No control row stores `jobInstanceId`, `rootActivityId`, pipeline run ID, or request ID, preventing definitive linkage from control events to Fabric jobs.
4. Generic run records have no notebook parameters or execution context beyond `jobType`, `invokeType`, status, timestamps, failure reason, and root activity ID.
5. The notebook-specific beta job-detail endpoint returned HTTP 404; the generic item detail endpoint did not provide additional execution payload.
6. Successful pipeline activity records have no explicit parent pipeline ID in the notebook job record; their associations here are based on job type and timing.
7. Job history is bounded to recent completed instances by the API specification. The records returned are the available response snapshot, not proof that no older run existed outside retention.

## 8. Recommended Next Investigation

1. If retained, obtain Monitoring Hub/Spark application logs and cell execution history for NB_01 runs `c8bcb4d1-153c-4a99-a1b2-75e1aa7bf630` and `1cc57ce0-d34f-4dbe-995c-15c45b6bfc71`, including the Python callable signature and cell ordering at the error time.
2. Retrieve any Fabric Git integration history or deployment/archive records for NB_01 around October 23 and compare them to the currently deployed source. Do not infer a source change from the error alone.
3. Check retained notebook session logs or operator records for repeated cell executions and in-memory variable resets during the 17:44–19:05 interactive session.
4. If available, obtain pipeline activity-level run records for the six Month-End parent IDs, especially the successful 08:32 run, to replace timing-based child associations with explicit parent-child links.
5. Locate the execution/control logging path for the 16:10–16:57 successful interactive session and determine whether its batch-summary append was skipped or failed. The current evidence only establishes that the source-file rows exist and the summary row does not.
