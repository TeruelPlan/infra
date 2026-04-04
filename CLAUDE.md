# CLAUDE.md

This file provides guidance to Claude when working with code in this repository.

## Overview

Docker Compose infrastructure for the PlanTogether platform. Orchestrates all external services needed for local
development: Traefik (reverse proxy), PostgreSQL (x7 databases), RabbitMQ, Redis, MinIO, and an observability stack
(Prometheus, Grafana, Loki, Tempo, Promtail).

## Commands

```bash
# Start essential services (traefik, postgres, rabbitmq, redis, minio)
docker compose up -d

# Start everything including observability
docker compose --profile monitoring up -d

# Check service health
docker compose ps

# Follow logs for a specific service
docker compose logs -f postgres

# Stop (keep volumes)
docker compose down

# Full reset — destroys all data
docker compose down -v
```

## Docker Compose profiles

| Profile      | Services                                   | Use when                             |
|--------------|--------------------------------------------|--------------------------------------|
| (default)    | traefik, postgres, rabbitmq, redis, minio  | Always — required for the app to run |
| `monitoring` | prometheus, grafana, loki, tempo, promtail | Optional — observability stack       |

## Service ports

| Service    | Port(s)       | UI / Notes                                                                                               |
|------------|---------------|----------------------------------------------------------------------------------------------------------|
| Traefik    | 80, 443, 8080 | http://localhost:8080 (dashboard)                                                                        |
| PostgreSQL | 5432          | 7 databases: `plantogether_trip`, `_poll`, `_destination`, `_expense`, `_task`, `_chat`, `_notification` |
| RabbitMQ   | 5672, 15672   | http://localhost:15672 (guest/guest)                                                                     |
| Redis      | 6379          | —                                                                                                        |
| MinIO      | 9000, 9001    | http://localhost:9001 (minioadmin/minioadmin)                                                            |
| Prometheus | 9090          | http://localhost:9090                                                                                    |
| Grafana    | 3000          | http://localhost:3000 (admin/admin)                                                                      |
| Loki       | 3100          | — (aggregates logs from Promtail)                                                                        |
| Tempo      | 3200, 4317    | 4317 = OTLP gRPC receiver for distributed tracing                                                        |

## Configuration

Secrets are set via a `.env` file (gitignored). Safe dev defaults apply if absent:

```bash
RABBITMQ_PASSWORD=guest
MINIO_PASSWORD=minioadmin
GRAFANA_PASSWORD=admin
```

## Key architecture details

### PostgreSQL

`postgres/init.sql` creates all 7 databases and their dedicated users at startup. Each microservice connects
to its own isolated database (Database per Service pattern). Schema is managed by Flyway inside each service —
never modified by Docker Compose directly.

### RabbitMQ

Single Topic Exchange: `plantogether.events`. All microservices publish to this exchange with service-specific
routing keys (e.g. `trip.created`, `expense.created`). The notification-service subscribes with `#` to receive
all events.

### Observability stack (Grafana)

All three observability pillars are integrated in Grafana with native correlation (click traceId in Loki →
opens trace in Tempo):

- **Prometheus** — scrapes Spring Actuator `/actuator/prometheus` from each service (JVM, HTTP, gRPC, custom metrics)
- **Loki + Promtail** — Promtail collects Docker container stdout/stderr logs (JSON format via
  `logback-logstash-encoder`) and pushes them to Loki
- **Tempo** — receives distributed traces via OTLP gRPC (port 4317) from Micrometer Tracing in each service

Grafana dashboards are provisioned automatically from `grafana/provisioning/` and `grafana/dashboards/`.

Pre-configured dashboards:
- JVM Overview (heap, GC, threads, CPU)
- Microservices Health (UP/DOWN, gRPC inter-service latency)
- RabbitMQ (published/consumed messages, dead letter queues)
- Business Metrics (trips created, expenses logged, active devices)
- Logs Explorer (Loki full-text search)
- Trace Explorer (Tempo flamegraph)

### Network

All containers share the `plantogether-network` Docker bridge network. Services reference each other by
container name (e.g. `postgres`, `rabbitmq`, `redis`, `traefik`).

## Directory structure

```
infra/
├── postgres/
│   └── init.sql                  # Creates all 7 databases + users
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/          # Prometheus, Loki, Tempo datasource configs
│   │   └── dashboards/           # Dashboard provisioning config
│   └── dashboards/               # Pre-built dashboard JSON files
├── prometheus/
│   └── prometheus.yml            # Scrape config (all microservices)
├── loki/
│   └── loki-config.yaml
└── tempo/
    └── tempo-config.yaml
```
