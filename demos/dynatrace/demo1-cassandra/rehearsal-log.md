# Rehearsal log

These are the test runs actually done. No full one-hour dry run of `start-demo.sh` has been performed yet.
Times are UTC on 2026-10-11 unless stated.

| # | Start | What ran | Result | Fix made afterwards |
|---|---|---|---|---|
| 1 | 02:24 | Burst start (200 threads, unthrottled) with the first detector and workflow | P95 crossed 200 at 02:25. First event 02:31. Workflow started on its own 02:32:35 and failed: `find_problem` returned no rows | Dropped the `ACTIVE` filter (it had already closed). Set `dt.davis.is_merging_allowed`. |
| 1b | 02:31 to 02:50 | Same run, detector merge flag off | About one Davis problem per minute (P-261027 to P-261042). Each ran the workflow; the runs that got a problem opened PRs #4 to #10 | Merge flag on |
| 2 | 15:19 | Burst again, detector re-created with merge allowed | P95 258 from 15:23. First event 15:26:55. Workflow ran on its own 15:26:33 and failed with the same empty `find_problem`. Problems P-261045 (15:23 to 15:24) and P-261050 (15:47 to 15:50) closed within 1 to 3 min | Workflow `find_problem` change (PR #14), applied in place |
| 3 | 15:53 | Manual workflow run after the fix | All 10 tasks SUCCESS in 1m16s. `find_problem` picked P-261050 (closed). PR #16 opened and linked. Email task SUCCESS (delivery not checked). PagerDuty stand-in returned `resolve` with `sent: false` because the burst had ended | none |
| 3b | 15:52 | Automatic run for P-261050 (same minute) | SUCCESS, opened PR #15, a duplicate of #16 | none (PRs #15 and #16 closed by hand) |

## Not rehearsed

- The `start-demo.sh baseline` and `spike 40` sequence, T-60 to T-0.
- A 40-minute burst: disk growth and whether a problem is open at the end.
- A click-through of `demo-script.md` against real screens.
- Email arriving in a mailbox.
