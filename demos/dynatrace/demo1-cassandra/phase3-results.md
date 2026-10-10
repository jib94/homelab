# Phase 3 - latency knob results (single run, 2026-10-10)

Metric: cassandra.clientRequest.write.latency.95thPercentile (assumed microseconds), pod cassandra-0.
Values are quantized: Cassandra reports histogram bucket edges (124, 149, 179, 215, 258, ...).

## Option A - pod CPU throttle (in-place resize): NOT POSSIBLE
`kubectl patch pod --subresource resize` is forbidden for the claude-rw identity (needs `get pods/resize`).
The only alternative is a StatefulSet patch, which restarts the pod and breaks the metric stream. Not tested, not chosen.

## Option B - burst write load (Deployment cassandra-stress-burst, 200 threads, no throttle): CHOSEN
| Event | Time from trigger | P95 |
|---|---|---|
| Baseline (10 min before) | - | 124 flat |
| degrade.sh (scale 0 -> 1) | +0 s | 124 |
| First rise | ~+92 s | 215 |
| Second rise | ~+214 s | 258 (held until reset) |
| reset.sh (scale 1 -> 0) | +0 s | 258 |
| First drop | ~+333 s | 215 |
| Still | +424 s (end of run) | 215, baseline 124 not yet reached |

No errors, no pod restarts. Disk +3 GB over the 8 min burst (62 GB node disk free after).

## Findings
- Rise is ~2x (0.12 -> 0.26 ms): small in absolute terms, clear in relative terms.
- Recovery is slow (>7 min to reach even 215). The JMX percentile is computed from a decaying window, so it lags.
- This does not fit a 12-13 min live run without help (see README plan: reset early, narrate recovery, or pre-open).
- ONE run only. Repeatability is not yet established; the three rehearsals must confirm.
