# Ecommerce Monitoring

Observability stack for the ecommerce microservices platform.

## Stack

| Tool | Purpose | Port |
|---|---|---|
| Prometheus | Metrics collection & storage | 9090 |
| Grafana | Dashboards & visualization | 3001 |
| Loki | Log aggregation | 3100 |
| Promtail | Log collector (Docker) | — |
| Tempo | Distributed tracing | 3200 / 4317 / 4318 |
| AlertManager | Alert routing | 9093 |
| cAdvisor | Container metrics | 9095 |
| Node Exporter | Host metrics | 9100 |
| Kafka Exporter | Kafka broker metrics | 9308 |
| Postgres Exporters | Database metrics | 9187–9193 |
| Blackbox Exporter | HTTP endpoint probing | 9115 |
| Nginx Exporter | Frontend nginx metrics | 9113 |

## Quick Start

The monitoring stack is embedded in the main ecommerce-platform docker-compose. Run the full stack from `ecommerce-platform/`:

```bash
cd ecommerce-platform
docker compose up --build
```

Or start only the monitoring services:

```bash
docker compose up prometheus grafana loki promtail tempo alertmanager \
  node-exporter cadvisor kafka-exporter blackbox-exporter nginx-exporter \
  postgres-exporter-userdb postgres-exporter-productdb postgres-exporter-orderdb \
  postgres-exporter-paymentdb postgres-exporter-shippingdb postgres-exporter-reviewdb \
  postgres-exporter-catalogdb
```

## Access

| URL | Service | Credentials |
|---|---|---|
| http://localhost:3000 | Frontend | — |
| http://localhost:3001 | **Grafana** | admin / admin |
| http://localhost:9090 | Prometheus | — |
| http://localhost:9093 | AlertManager | — |
| http://localhost:3200 | Tempo | — |
| http://localhost:8080 | API Gateway | — |
| http://localhost:8761 | Eureka | — |

## Grafana Dashboards

Eight dashboards are auto-provisioned on startup:

| Dashboard | What it shows |
|---|---|
| Platform Overview | Service UP/DOWN, request rate, error rate, P99 latency, Kafka lag |
| JVM Metrics | Heap, GC, threads, CPU, HikariCP pool per service |
| API Gateway | Route-level request rate, latency percentiles, error breakdown |
| Databases | PostgreSQL connections, transactions, cache hit ratio, deadlocks |
| Kafka | Broker health, consumer group lag, topic message rate |
| Containers & Infrastructure | Container CPU/memory, host CPU/memory/disk/network |
| Frontend & Availability | Nginx metrics, blackbox endpoint probes, probe duration |
| Error & Latency Overview | Error rates, P50/P90/P99 by service, top slowest/error endpoints |

## What is Instrumented

### Spring Boot Services (all 9)
- `/actuator/prometheus` — Prometheus scrape endpoint
- JVM metrics (heap, GC, threads, classes)
- HTTP request metrics with SLO histograms (50ms/100ms/200ms/500ms/1s/2s)
- HikariCP connection pool metrics
- Resilience4j circuit breaker metrics
- OTLP traces sent to Tempo on port 4318
- Logs with `[traceId/spanId]` in every line for correlation

### Infrastructure
- **cAdvisor** — CPU, memory, network, disk I/O per container
- **Node Exporter** — Host-level CPU, memory, disk, network
- **Kafka Exporter** — Broker count, consumer group lag, topic offsets
- **Postgres Exporters** — One per database (userdb, productdb, orderdb, paymentdb, shippingdb, reviewdb, catalogdb)
- **Blackbox Exporter** — HTTP probes for all 9 service health endpoints + frontend
- **Nginx Exporter** — Frontend nginx active connections, request rate

### Logging (Loki + Promtail)
- All application container logs collected via Docker socket
- Parsed for `level`, `correlationId`, `traceId` labels
- DEBUG logs dropped to reduce volume
- Searchable in Grafana → Explore → Loki

### Tracing (Tempo)
- All services export OTLP traces to Tempo
- Trace IDs correlated with logs via `traceId` label
- Service graph and span metrics auto-generated
- Viewable in Grafana → Explore → Tempo

## Alert Rules

Four alert groups:

| File | Alerts |
|---|---|
| `service-alerts.yml` | ServiceDown, HighErrorRate, CriticalErrorRate, HighP99Latency, JvmHeapHigh, GcPauseHigh, CircuitBreakerOpen |
| `infrastructure-alerts.yml` | ContainerHighCpu, ContainerHighMemory, HostHighCpu, HostOutOfMemory, HostDiskLow |
| `database-alerts.yml` | PostgresDown, TooManyConnections, Deadlocks, SlowQueries |
| `kafka-alerts.yml` | KafkaBrokerDown, ConsumerGroupLag, TopicOffsetNotGrowing |

## Configuration

Copy `.env.example` to `.env` in the `ecommerce-platform` directory and adjust as needed.

Key variables:
- `GRAFANA_ADMIN_PASSWORD` — change before deploying anywhere non-local
- `TRACING_SAMPLING_PROBABILITY` — set to `0.1` (10%) for high-traffic environments
- `JWT_SECRET` — must match across all services

## Alerting

Edit `alertmanager/alertmanager.yml` to configure a real notification channel:
- **Slack**: uncomment the `slack_configs` section and set `SLACK_WEBHOOK_URL`
- **Email**: set `smtp_*` globals and configure SMTP receiver
- **PagerDuty**: use `pagerduty_configs`

## Directory Structure

```
ecommerce-monitoring/
├── prometheus/
│   ├── prometheus.yml          # Scrape config for all 20+ targets
│   └── rules/
│       ├── service-alerts.yml
│       ├── infrastructure-alerts.yml
│       ├── database-alerts.yml
│       └── kafka-alerts.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/        # Prometheus + Loki + Tempo auto-configured
│   │   └── dashboards/         # Dashboard provider config
│   └── dashboards/             # 8 JSON dashboard files
├── loki/
│   └── loki-config.yml         # 31-day retention, local filesystem
├── promtail/
│   └── promtail-config.yml     # Docker socket log collection
├── tempo/
│   └── tempo-config.yml        # OTLP gRPC+HTTP, 48h retention
├── alertmanager/
│   └── alertmanager.yml        # Route + receiver config
├── blackbox-exporter/
│   └── blackbox-config.yml
└── postgres-exporter/
    └── queries.yml             # Custom queries (slow queries, bloat, connection states)
```
