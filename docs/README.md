# Project documentation

Read current source together with the contracts below. A report's PASS/PARTIAL
applies to its recorded revision and workload; it does not certify today's dirty
worktree or full device acceptance.

| Topic | Canonical guidance |
| --- | --- |
| Setup and product overview | [Repository README](../README.md) |
| Product requirements | [APP_SPEC_VI](APP_SPEC_VI.md) |
| Dependency research, including superseded proposals | [TECH_STACK_RESEARCH_VI](TECH_STACK_RESEARCH_VI.md) |
| Ownership and cross-feature interfaces | [P2/P3 contracts](implementation/P2_P3_CONTRACTS.md), [P1 capture contract](p1/TASK_00_OWNERSHIP_AND_CONTRACT.md) |
| Architecture and feature status | Contracts above plus the dated [UI/UX 06 implementation report](reports/TASK_UI_UX_06_20261111_172021_ffa4c9/TASK_UI_UX_06_EDITOR_REDESIGN_REPORT_v2.md); verify current source before edits |
| UX rules | [Human-centered UX contract](3HRecorder_TASK_03_1_UX_GUIDELINES.md) |
| Design system and visual evidence | [UI index](ui/README.md), [design system](ui/DESIGN_SYSTEM.md) |
| Native reuse, provenance and licensing | [Reuse register](implementation/REUSE_REGISTER.md), [bundled notices](../assets/licenses/) |
| Historical data incident and recovery limitations | [Recovery status](implementation/TASK_08_DATA_RECOVERY_FINAL_STATUS.md) |
| TASK09B scope and open gates | [Final report](implementation/TASK_09B_FINAL_REPORT_VI.md), [P1 handoff](implementation/TASK_09B_P1_HANDOFF_UPDATE.md) |
| Testing instructions and acceptance criteria | [TASK09B test evidence](implementation/TASK_09B_TEST_EVIDENCE.md), [acceptance checklist](TASK_09B_ACCEPTANCE_CHECKLIST.md) |
| Globalization and speech interfaces | [Globalization matrix](implementation/TASK_07_GLOBALIZATION_MATRIX.md), [ASR contract](implementation/TASK_07_ASR_CONTRACT_AND_BENCHMARK.md) |
| Known bugs and TASK10 prerequisites | [Bug register](implementation/TASK_09B_BUG_REGISTER.md), [scenario gaps](implementation/TASK_09B_SCENARIO_MATRIX.md), P1/UI06 handoffs below; TASK10 has not started |
| Latest UI/UX 06 editor checkpoint | [Version 2 report](reports/TASK_UI_UX_06_20261111_172021_ffa4c9/TASK_UI_UX_06_EDITOR_REDESIGN_REPORT_v2.md), [P1 follow-up](reports/TASK_UI_UX_06_20261111_172021_ffa4c9/P1_UI06_HANDOFF.md) |
| TASK09C maintenance and preservation | [Handoff](reports/TASK_09C_20261113/FINAL_HANDOFF.md) |
| Historical retention and storage decisions | [TASK09D handoff](reports/TASK_09D_20261113/FINAL_HANDOFF.md), [approval manifest](reports/TASK_09D_20261113/CLEANUP_APPROVAL_MANIFEST.md) |

`implementation/` retains feature contracts, handoffs and historical task reports;
`p1/` belongs to P1; `reports/` retains task-scoped raw evidence and reproduction
scripts; `xrecorder/` retains earlier phase validations. `ui/` and `performance/`
provide subject indexes. Existing report paths stay stable for reproducibility.

TASK09B and UI/UX 06 remain PARTIAL. Four historical Recording Setup failures,
the UI/UX 06 capture-journal metadata discrepancy, physical-device/human testing
and QA5560 recovery limitations remain documented in their original reports.
TASK09C is host-only maintenance and does not start TASK10.

Keep failed attempts, incident records, recovery manifests, retained media and
models. A file being ignored by Git or living under `build/` does not authorize
deletion. Historical reports are not consolidated by overwriting newer verdicts
onto older evidence.
