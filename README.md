# PlanTogether — Infrastructure

> Single repo for all PlanTogether deployment: Docker Compose (local dev) and Kubernetes/Helm (production).

## Structure

```
infra/
├── docker-compose.yml            # Local development environment
├── docker-compose.prod.yml       # Production overrides (Docker Compose)
│
├── helm/                         # Kubernetes deployment (production)
│   ├── helmfile.yaml             # Orchestration for all releases
│   ├── charts/
│   │   └── plantogether-service/ # Generic shared Helm chart (all microservices)
│   │       ├── Chart.yaml
│   │       ├── values.yaml       # Default values
│   │       └── templates/        # deployment, service, ingress, hpa, _helpers
│   ├── values/
│   │   ├── infra/                # traefik, postgresql, redis, rabbitmq, minio, argocd
│   │   ├── app/                  # One file per microservice
│   │   └── monitoring/           # kube-prometheus-stack, loki, tempo
│   └── environments/
│       ├── dev.yaml              # 1 replica, debug, lightweight resources
│       ├── staging.yaml
│       └── prod.yaml             # 2+ replicas, HPA, full resources
│
├── postgres/
│   └── init.sql                  # Creates all 7 PostgreSQL databases at startup
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/          # Prometheus, Loki, Tempo
│   │   └── dashboards/
│   └── dashboards/               # Pre-configured dashboard JSON files
├── prometheus/
│   └── prometheus.yml
├── loki/
│   └── loki-config.yml
└── tempo/
    └── tempo.yml
```

---

## Local Dev — Docker Compose

The local environment orchestrates all external services needed for PlanTogether to run.

### Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- At least 4 GB of available RAM

### Startup

```bash
# Essential services (Traefik, PostgreSQL, RabbitMQ, Redis, MinIO)
docker compose up -d

# With the observability stack (+ Prometheus, Grafana, Loki, Tempo, Promtail)
docker compose --profile monitoring up -d

# Check status
docker compose ps

# Logs for a service
docker compose logs -f postgres

# Stop (preserve volumes)
docker compose down

# Full reset (destroys all data)
docker compose down -v
```

### Local Ports

| Service    | Port(s)         | UI                                            |
|------------|-----------------|-----------------------------------------------|
| Traefik    | 80 / 443 / 8080 | http://localhost:8080 (dashboard)             |
| PostgreSQL | 5432            | — (7 isolated databases)                      |
| RabbitMQ   | 5672, 15672     | http://localhost:15672 (guest/guest)          |
| Redis      | 6379            | —                                             |
| MinIO      | 9000, 9001      | http://localhost:9001 (minioadmin/minioadmin) |
| Prometheus | 9090            | http://localhost:9090                         |
| Grafana    | 3000            | http://localhost:3000 (admin/admin)           |
| Loki       | 3100            | —                                             |
| Tempo      | 3200, 4317      | 4317 = OTLP gRPC (traces)                     |

### Environment Variables (.env)

Copy `.env.example` to `.env` and adjust:

```bash
RABBITMQ_PASSWORD=guest
MINIO_PASSWORD=minioadmin
GRAFANA_PASSWORD=admin
```

### Recommended Startup Order

1. `docker compose up -d` — wait until PostgreSQL is `healthy`
2. `cd ../plantogether-proto && mvn clean install`
3. `cd ../plantogether-common && mvn clean install`
4. Start microservices in their respective repos (`mvn spring-boot:run`)

---

## Production — Kubernetes (Kind + Helm + Helmfile)

In production, infrastructure runs on a **Kind** (Kubernetes in Docker) cluster hosted on a VPS,
packaged with **Helm** and orchestrated by **Helmfile**. **ArgoCD** handles continuous deployment (GitOps).

### Prerequisites

- `helm` 3.x + `helmfile` 0.x
- `kubectl` configured for the Kind cluster

### Helmfile Commands

```bash
# From infra/helm/

# Deploy entire cluster
helmfile -e prod sync

# Preview changes before applying
helmfile -e prod diff

# Microservices only (without touching infra)
helmfile -e prod -l tier=app sync

# A specific service
helmfile -e prod -l name=trip-service sync

# Rollback
helm rollback trip-service -n app
```

### Cluster Architecture

```
namespace: traefik     → Traefik Ingress Controller (NodePort 30080/30443)
namespace: infra       → PostgreSQL · Redis · RabbitMQ · MinIO · ArgoCD
namespace: app         → 8 microservices (1-2 replicas, HPA in prod)
namespace: monitoring  → Prometheus · Grafana · Loki · Tempo · Promtail
```

### Generic Chart (`charts/plantogether-service`)

A single shared Helm chart for all microservices. Each `values/app/{service}.yaml` overrides
only what changes (image, port, Ingress path, gRPC, env vars).

| Parameter                    | Example                                        | Description                |
|------------------------------|------------------------------------------------|----------------------------|
| `image.repository`           | `ghcr.io/TeruelPlan/plantogether-trip-service` | Docker image               |
| `image.tag`                  | `sha-abc123`                                   | Auto-updated by CI         |
| `service.port`               | `8081`                                         | REST port                  |
| `grpc.enabled` / `grpc.port` | `true` / `9081`                                | gRPC port                  |
| `ingress.path`               | `/api/v1/trips`                                | Traefik PathPrefix         |
| `replicas`                   | `1` dev / `2` prod                             | Replica count              |
| `hpa.enabled`                | `true` in prod                                 | CPU autoscaling            |
| `envFromSecret`              | `plantogether-secrets`                         | K8s Secret for credentials |

### GitOps with ArgoCD

**CI** (GitHub Actions, in each service repo): build → test → push image → commit new tag in
`helm/values/app/{service}.yaml`

**CD** (ArgoCD, watches this repo): detects commit → `helm upgrade` → rolling update zero-downtime → auto rollback if
healthcheck fails

### Bootstrap — Kubernetes Secrets

```bash
kubectl create secret generic plantogether-secrets -n app \
  --from-literal=DB_PASSWORD=xxx \
  --from-literal=RABBITMQ_PASSWORD=xxx \
  --from-literal=MINIO_SECRET_KEY=xxx \
  --from-literal=FCM_SERVER_KEY=xxx
```

---

## Observability (Grafana Stack)

| Pillar  | Tool            | Source                                                   |
|---------|-----------------|----------------------------------------------------------|
| Metrics | Prometheus      | Spring Actuator `/actuator/prometheus` (each service)    |
| Logs    | Loki + Promtail | Pod stdout/stderr (structured JSON via logback)          |
| Traces  | Tempo           | OTLP gRPC port 4317 (Micrometer Tracing / OpenTelemetry) |

Everything is correlated in Grafana: clicking a `traceId` in logs opens the trace directly in Tempo.

Pre-configured dashboards: JVM Overview · Microservices Health · RabbitMQ · Business Metrics ·
Logs Explorer · Trace Explorer.

---

## Useful Commands

```bash
# PostgreSQL (dev)
docker compose exec postgres psql -U plantogether -d plantogether_trip

# Redis CLI (dev)
docker compose exec redis redis-cli

# RabbitMQ status
curl http://localhost:15672/api/overview -u guest:guest

# K8s — view all pods
kubectl get pods -A

# K8s — service logs
kubectl logs -n app deployment/trip-service -f
```

## Documentation

- [Helmfile](https://helmfile.readthedocs.io/)
- [Helm](https://helm.sh/docs/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Traefik](https://doc.traefik.io/traefik/)
- [Kind](https://kind.sigs.k8s.io/)
- [Grafana Stack](https://grafana.com/docs/)
