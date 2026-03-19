# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains the Docker Compose infrastructure for the PlanTogether platform. It orchestrates all external services needed for local development: Keycloak (IAM), PostgreSQL, RabbitMQ, Redis, MinIO, and an observability stack (Prometheus, Grafana, Loki, Tempo).

The main entry point is `docker-compose.yml` at the repository root. Service-specific configuration files live in their respective subdirectories (`keycloak/`, `postgres/`, `grafana/`, etc.).

## Common Commands

```bash
# Start essential services only (postgres, keycloak, rabbitmq, redis, minio)
docker compose --profile essential up -d

# Start monitoring stack only (prometheus, grafana, loki, tempo)
docker compose --profile monitoring up -d

# Start everything
docker compose --profile essential --profile monitoring up -d

# Check service health
docker compose ps

# Follow logs for a specific service
docker compose logs -f keycloak

# Stop and remove all containers (keep volumes)
docker compose down

# Full reset including volumes (destroys all data)
docker compose down -v
```

## Docker Compose Profiles

Services are split into two profiles to allow lighter dev environments:

- **`essential`**: postgres, keycloak, rabbitmq, redis, minio — required for the application to run
- **`monitoring`**: prometheus, grafana, loki, tempo — optional observability stack

## Configuration

Secrets and passwords are configured via a `.env` file (gitignored). Copy and adjust:

```bash
KEYCLOAK_ADMIN_PASSWORD=admin
KEYCLOAK_DB_PASSWORD=keycloak_password
RABBITMQ_PASSWORD=guest
MINIO_PASSWORD=minioadmin
GRAFANA_PASSWORD=admin
```

All passwords default to dev-safe values if `.env` is absent.

## Service Ports

| Service    | Port(s)         | UI                              |
|------------|-----------------|----------------------------------|
| Keycloak   | 8080            | http://localhost:8080/admin     |
| PostgreSQL | 5432            | —                               |
| RabbitMQ   | 5672, 15672     | http://localhost:15672          |
| Redis      | 6379            | —                               |
| MinIO      | 9000, 9001      | http://localhost:9001           |
| Prometheus | 9090            | http://localhost:9090           |
| Grafana    | 3000            | http://localhost:3000           |
| Loki       | 3100            | —                               |
| Tempo      | 3200, 4317      | —                               |

## Key Architecture Details

- **Keycloak** is pre-configured with the `plantogether` realm via `keycloak/realm-export.json` (mounted at import path on startup). It runs in `start-dev` mode backed by PostgreSQL.
- **PostgreSQL** runs an init script at `postgres/init.sql` that creates the `keycloak`, `plantogether`, and `plantogether_test` databases with dedicated users.
- **Grafana** datasources and dashboards are provisioned automatically from `grafana/provisioning/` and `grafana/dashboards/`.
- **Tempo** exposes an OTLP gRPC receiver on port 4317 for distributed tracing from application services.
- All services share a single Docker network named `plantogether-network`.
