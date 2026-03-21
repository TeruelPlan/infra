# CLAUDE.md

This file provides guidance to Claude when working with code in this repository.

## Overview

Docker Compose infrastructure for the PlanTogether platform. Orchestrates all external services needed for local
development: Keycloak (IAM), PostgreSQL (x8 databases), RabbitMQ, Redis, MinIO, and an observability stack
(Prometheus, Grafana, Loki, Tempo, Promtail).

## Commands

```bash
# Start essential services (postgres, keycloak, rabbitmq, redis, minio)
docker compose --profile essential up -d

# Start everything including observability
docker compose --profile essential --profile monitoring up -d

# Check service health
docker compose ps

# Follow logs for a specific service
docker compose logs -f keycloak

# Stop (keep volumes)
docker compose down

# Full reset — destroys all data
docker compose down -v
```

## Docker Compose profiles

| Profile | Services | Use when |
|---|---|---|
| `essential` | postgres, keycloak, rabbitmq, redis, minio | Always — required for the app to run |
| `monitoring` | prometheus, grafana, loki, tempo, promtail | Optional — observability stack |

## Service ports

| Service | Port(s) | UI / Notes |
|---|---|---|
| Keycloak | 8180 | http://localhost:8180/admin (admin/admin) — port 8180 to avoid conflict with Traefik dashboard on 8080 |
| PostgreSQL | 5432 | 8 databases: `plantogether_trip`, `_poll`, `_destination`, `_expense`, `_task`, `_chat`, `_notification`, `keycloak` |
| RabbitMQ | 5672, 15672 | http://localhost:15672 (guest/guest) |
| Redis | 6379 | — |
| MinIO | 9000, 9001 | http://localhost:9001 (minioadmin/minioadmin) |
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 (admin/admin) |
| Loki | 3100 | — (aggregates logs from Promtail) |
| Tempo | 3200, 4317 | 4317 = OTLP gRPC receiver for distributed tracing |

## Configuration

Secrets are set via a `.env` file (gitignored). Safe dev defaults apply if absent:

```bash
KEYCLOAK_ADMIN_PASSWORD=admin
KEYCLOAK_DB_PASSWORD=keycloak_password
RABBITMQ_PASSWORD=guest
MINIO_PASSWORD=minioadmin
GRAFANA_PASSWORD=admin
```

## Key architecture details

### PostgreSQL

`postgres/init.sql` creates all 8 databases and their dedicated users at startup. Each microservice connects
to its own isolated database (Database per Service pattern). Schema is managed by Flyway inside each service —
never modified by Docker Compose directly.

### Keycloak

Pre-configured with the `plantogether` realm via `keycloak/realm-export.json` (imported automatically on
first start). Runs in `start-dev` mode backed by PostgreSQL. Configured clients:

| Client | Type | Purpose |
|---|---|---|
| `plantogether-app` | Public + PKCE | Flutter mobile/web client |
| `plantogether-api` | Confidential bearer-only | JWT validation by microservices |
| `plantogether-admin` | Service account | Keycloak Admin API (batch user lookup) |

Identity Providers configured: Google, Apple, Facebook.

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
- API Gateway (req/sec, P50/P95/P99 latency, 4xx/5xx rates)
- Microservices Health (UP/DOWN, gRPC inter-service latency)
- RabbitMQ (published/consumed messages, dead letter queues)
- Business Metrics (trips created, expenses logged, active users)
- Logs Explorer (Loki full-text search)
- Trace Explorer (Tempo flamegraph)

### Network

All containers share the `plantogether-network` Docker bridge network. Services reference each other by
container name (e.g. `postgres`, `rabbitmq`, `redis`, `keycloak`).

## Directory structure

```
infra/
├── keycloak/
│   └── realm-export.json         # Realm config imported on first start
├── postgres/
│   └── init.sql                  # Creates all 8 databases + users
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
