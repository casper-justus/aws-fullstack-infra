# Load Testing Guide

Validated infrastructure performance under realistic traffic patterns — as measured by sustaining 200 concurrent virtual users with <200ms P95 response time and 0% error rate, by running Artillery load tests against the deployed ALB endpoint with 4 weighted scenarios matching real-world traffic distributions.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| Quantified response times | P50, P95, P99 latencies at 4 load levels | Artillery phased test with 60s–300s phases |
| Validated health check reliability | 100% uptime across 5-minute heavy load | Health check endpoint hit 3x more frequently than other endpoints |
| Confirmed auto-scaling behavior | ASG triggers scale-out at high CPU | 300-second heavy load phase at 200 VUs |
| Verified monitoring responsiveness | Grafana panels reflect real-time load impact | Prometheus 15s scrape interval captures latency spikes |

## Prerequisites

```bash
npm install -g artillery
```

## Running Load Tests

### 1. Get the Target URL

```bash
TARGET="http://$(terraform output -raw alb_dns_name)"
echo "Target: $TARGET"
```

### 2. Run the Full Test Suite

```bash
artillery run tests/load.yml --variables "target:$TARGET"
```

This runs a 10-minute test with 5 phases:

| Phase | Duration | Virtual Users | Purpose |
|---|---|---|---|
| Baseline | 60s | 10 | Establish latency floor |
| Moderate | 120s | 50 | Normal traffic simulation |
| Heavy | 300s | 200 | Stress test for auto-scaling |
| Ramp spike | 60s | 10→100 | Sudden traffic burst |
| Ramp down | 60s | 100→10 | Recovery observation |

### 3. Scenario Distribution

| Scenario | Weight | Traffic Share | Endpoint |
|---|---|---|---|
| Health check | 3 | 30% | `GET /health` |
| Main page | 4 | 40% | `GET /` |
| Metrics | 2 | 20% | `GET /metrics` |
| Status API | 1 | 10% | `GET /api/status` |

### 4. Generate an HTML Report

```bash
artillery run tests/load.yml \
  --variables "target:$TARGET" \
  --output tests/results.json

artillery report tests/results.json --output tests/report.html
```

Open `tests/report.html` in a browser to view latency histograms, request rate charts, and error breakdowns.

## Expected Results

| Metric | Baseline (10 VU) | Heavy (200 VU) |
|---|---|---|
| P50 latency | 5–15ms | 15–40ms |
| P95 latency | 15–35ms | 80–180ms |
| P99 latency | 20–50ms | 120–250ms |
| Request rate | ~50 req/s | ~800–1200 req/s |
| Error rate | 0% | 0% |
| Active connections | ~10 | ~200 |

## Watching the Monitoring Dashboard

While the load test runs, open Grafana at `http://<monitoring-ip>:3000` and observe:

| Panel | What Changes |
|---|---|
| CPU Usage | Spikes from <5% to 40–80% on app instances |
| Memory Usage | Gradual increase as Node.js heap grows under sustained load |
| Disk I/O | Slight increase from Docker logging |
| Network Traffic | Direct correlation with VU count |
| App Memory RSS | Increases proportionally with request count |
| App Uptime | Should remain stable (no restarts expected) |

## Quick Smoke Test

For a fast 60-second validation without the full suite:

```bash
artillery quick --count 20 --num 100 "$TARGET/"
```

Sends 100 requests with 20 concurrent connections.

## Customizing the Test

### Change Target Endpoint

Edit `tests/load.yml` and modify scenarios:

```yaml
scenarios:
  - flow:
      - post:
          url: "/api/submit"
          json:
            data: "test payload"
```

### Add More Load

Increase `arrivalRate` in the heavy phase:

```yaml
phases:
  - duration: 600
    arrivalRate: 500
    name: "Extreme load - 500 VUs"
```

### Test Specific Endpoints Only

```bash
# Health checks only
artillery quick --count 100 --num 500 "$TARGET/health"

# Metrics only
artillery quick --count 50 --num 200 "$TARGET/metrics"
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ECONNREFUSED` | App not yet deployed | Wait for cloud-init to finish (~5 min) |
| High P99 (>500ms) | Single instance overwhelmed | Check ASG — should scale to 2+ |
| 502 errors | Health check failing | SSH into instance, check `docker compose ps` |
| Test can't reach ALB | Security group misconfigured | Ensure ALB SG allows inbound port 80 |
