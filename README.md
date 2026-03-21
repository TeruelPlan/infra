# PlanTogether — Infrastructure

> Repo unique pour tout le déploiement PlanTogether : Docker Compose (dev local) et Kubernetes/Helm (production).

## Structure

```
infra/
├── docker-compose.yml            # Environnement de développement local
├── docker-compose.prod.yml       # Overrides production (Docker Compose)
│
├── helm/                         # Déploiement Kubernetes (production)
│   ├── helmfile.yaml             # Orchestration de tous les releases
│   ├── charts/
│   │   └── plantogether-service/ # Chart Helm générique partagé (tous les microservices)
│   │       ├── Chart.yaml
│   │       ├── values.yaml       # Valeurs par défaut
│   │       └── templates/        # deployment, service, ingress, hpa, _helpers
│   ├── values/
│   │   ├── infra/                # traefik, keycloak, postgresql, redis, rabbitmq, minio, argocd
│   │   ├── app/                  # Un fichier par microservice
│   │   └── monitoring/           # kube-prometheus-stack, loki, tempo
│   └── environments/
│       ├── dev.yaml              # 1 replica, debug, resources légers
│       ├── staging.yaml
│       └── prod.yaml             # 2+ replicas, HPA, resources complets
│
├── keycloak/
│   ├── realm-export.json         # Realm plantogether (importé au démarrage)
│   └── providers/                # JAR du Keycloak SPI (plantogether-keycloak-spi)
├── postgres/
│   └── init.sql                  # Création des 8 bases PostgreSQL au démarrage
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/          # Prometheus, Loki, Tempo
│   │   └── dashboards/
│   └── dashboards/               # JSON des dashboards préconfigurés
├── prometheus/
│   └── prometheus.yml
├── loki/
│   └── loki-config.yml
└── tempo/
    └── tempo.yml
```

---

## Dev local — Docker Compose

L'environnement local orchestre tous les services externes nécessaires au fonctionnement de PlanTogether.

### Prérequis

- Docker 20.10+ et Docker Compose 2.0+
- Au minimum 6 Go de RAM disponible

### Démarrage

```bash
# Services essentiels (Keycloak, PostgreSQL, RabbitMQ, Redis, MinIO)
docker compose --profile essential up -d

# Avec la stack d'observabilité (+ Prometheus, Grafana, Loki, Tempo, Promtail)
docker compose --profile essential --profile monitoring up -d

# Vérifier l'état
docker compose ps

# Logs d'un service
docker compose logs -f keycloak

# Arrêt (conserve les volumes)
docker compose down

# Réinitialisation complète (détruit toutes les données)
docker compose down -v
```

### Profils Docker Compose

| Profil | Services | Usage |
|---|---|---|
| `essential` | keycloak, postgres, rabbitmq, redis, minio | Toujours requis |
| `monitoring` | prometheus, grafana, loki, tempo, promtail | Optionnel |

### Ports locaux

| Service | Port(s) | UI |
|---|---|---|
| Keycloak | **8180** | http://localhost:8180/admin (admin/admin) |
| PostgreSQL | 5432 | — (8 bases isolées) |
| RabbitMQ | 5672, 15672 | http://localhost:15672 (guest/guest) |
| Redis | 6379 | — |
| MinIO | 9000, 9001 | http://localhost:9001 (minioadmin/minioadmin) |
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 (admin/admin) |
| Loki | 3100 | — |
| Tempo | 3200, 4317 | 4317 = OTLP gRPC (traces) |

> Keycloak tourne sur **8180** pour éviter le conflit avec la Gateway (8080).

### Variables d'environnement (.env)

Copier `.env.example` → `.env` et ajuster :

```bash
KEYCLOAK_ADMIN_PASSWORD=admin
KEYCLOAK_DB_PASSWORD=keycloak_password
RABBITMQ_PASSWORD=guest
MINIO_PASSWORD=minioadmin
GRAFANA_PASSWORD=admin
```

### Ordre de démarrage recommandé

1. `docker compose --profile essential up -d` — attendre que PostgreSQL et Keycloak soient `healthy`
2. `cd ../plantogether-proto && mvn clean install`
3. `cd ../plantogether-common && mvn clean install`
4. Démarrer les microservices dans leurs repos respectifs (`mvn spring-boot:run`)

---

## Production — Kubernetes (Kind + Helm + Helmfile)

En production, l'infrastructure tourne sur un cluster **Kind** (Kubernetes in Docker) hébergé sur VPS,
packagée avec **Helm** et orchestrée par **Helmfile**. **ArgoCD** assure le déploiement continu (GitOps).

### Prérequis

- `helm` 3.x + `helmfile` 0.x
- `kubectl` configuré sur le cluster Kind

### Commandes Helmfile

```bash
# Depuis infra/helm/

# Déployer tout le cluster
helmfile -e prod sync

# Voir les changements avant d'appliquer
helmfile -e prod diff

# Microservices uniquement (sans toucher à l'infra)
helmfile -e prod -l tier=app sync

# Un service spécifique
helmfile -e prod -l name=trip-service sync

# Rollback
helm rollback trip-service -n app
```

### Architecture du cluster

```
namespace: traefik     → Traefik Ingress Controller (NodePort 30080/30443)
namespace: infra       → Keycloak · PostgreSQL · Redis · RabbitMQ · MinIO · ArgoCD
namespace: app         → 8 microservices + Gateway + Eureka (1-2 replicas, HPA en prod)
namespace: monitoring  → Prometheus · Grafana · Loki · Tempo · Promtail
```

### Chart générique (`charts/plantogether-service`)

Un seul chart Helm partagé par tous les microservices. Chaque `values/app/{service}.yaml` surcharge
uniquement ce qui change (image, port, path Ingress, gRPC, env vars).

| Paramètre | Exemple | Description |
|---|---|---|
| `image.repository` | `ghcr.io/TeruelPlan/plantogether-trip-service` | Image Docker |
| `image.tag` | `sha-abc123` | Mis à jour automatiquement par la CI |
| `service.port` | `8081` | Port REST |
| `grpc.enabled` / `grpc.port` | `true` / `9081` | Port gRPC |
| `ingress.path` | `/api/v1/trips` | PathPrefix Traefik |
| `replicas` | `1` dev / `2` prod | Nombre de replicas |
| `hpa.enabled` | `true` en prod | Autoscaling CPU |
| `envFromSecret` | `plantogether-secrets` | Secret K8s pour les credentials |

### GitOps avec ArgoCD

**CI** (GitHub Actions, dans chaque repo service) : build → tests → push image → commit du nouveau tag dans `helm/values/app/{service}.yaml`

**CD** (ArgoCD, surveille ce repo) : détecte le commit → `helm upgrade` → rolling update zero-downtime → rollback auto si healthcheck échoue

### Bootstrap — Secrets Kubernetes

```bash
kubectl create secret generic plantogether-secrets -n app \
  --from-literal=DB_PASSWORD=xxx \
  --from-literal=RABBITMQ_PASSWORD=xxx \
  --from-literal=MINIO_SECRET_KEY=xxx \
  --from-literal=KEYCLOAK_CLIENT_SECRET=xxx \
  --from-literal=FCM_SERVER_KEY=xxx
```

---

## Observabilité (Grafana Stack)

| Pilier | Outil | Source |
|---|---|---|
| Métriques | Prometheus | Spring Actuator `/actuator/prometheus` (chaque service) |
| Logs | Loki + Promtail | Stdout/stderr des pods (JSON structuré via logback) |
| Traces | Tempo | OTLP gRPC port 4317 (Micrometer Tracing / OpenTelemetry) |

Tout est corrélé dans Grafana : cliquer sur un `traceId` dans les logs ouvre directement la trace dans Tempo.

Dashboards préconfigurés : JVM Overview · API Gateway · Microservices Health · RabbitMQ · Business Metrics ·
Logs Explorer · Trace Explorer.

---

## Commandes utiles

```bash
# PostgreSQL (dev)
docker compose exec postgres psql -U plantogether -d plantogether_trip

# Redis CLI (dev)
docker compose exec redis redis-cli

# Statut RabbitMQ
curl http://localhost:15672/api/overview -u guest:guest

# Santé Keycloak
curl http://localhost:8180/realms/plantogether

# K8s — voir tous les pods
kubectl get pods -A

# K8s — logs d'un service
kubectl logs -n app deployment/trip-service -f
```

## Documentation

- [Helmfile](https://helmfile.readthedocs.io/)
- [Helm](https://helm.sh/docs/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Traefik](https://doc.traefik.io/traefik/)
- [Kind](https://kind.sigs.k8s.io/)
- [Keycloak](https://www.keycloak.org/documentation)
- [Grafana Stack](https://grafana.com/docs/)
