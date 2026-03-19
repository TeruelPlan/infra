# PlanTogether Infrastructure

> Stack Docker Compose complet pour la plateforme PlanTogether en développement local

## Rôle

Le projet infra fournit une configuration Docker Compose orchestrant tous les services externes et infrastructure
nécessaires au fonctionnement de PlanTogether. Elle inclut Keycloak pour l'IAM, PostgreSQL pour les données, RabbitMQ
pour la messagerie asynchrone, Redis pour le cache, MinIO pour le stockage objet, et le stack d'observabilité (
Prometheus, Grafana, Loki, Tempo).

### Fonctionnalités

- **Orchestration Docker Compose** : Lancement de tous les services avec une seule commande
- **Keycloak 24+** : IAM centralisé avec realm plantogether
- **PostgreSQL 16** : Base de données relationnelle
- **RabbitMQ 3.13** : Courtier de messages pour communication asynchrone
- **Redis 7** : Cache en mémoire haute performance
- **MinIO** : Stockage objet S3-compatible
- **Prometheus** : Collecte des métriques
- **Grafana** : Visualisation des métriques et dashboards
- **Loki** : Agrégation des logs
- **Tempo** : Tracing distribué

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│         Docker Compose Infrastructure                     │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Identity & Access Management                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Keycloak 24 (port 8080)                    │  │  │
│  │  │  Realm: plantogether                        │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Persistent Storage                              │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  │  │
│  │  │  PostgreSQL 16     │  │  Redis 7           │  │  │
│  │  │  (port 5432)       │  │  (port 6379)       │  │  │
│  │  └────────────────────┘  └────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Messaging & Storage                             │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  │  │
│  │  │  RabbitMQ 3.13     │  │  MinIO             │  │  │
│  │  │  (port 5672/15672) │  │  (port 9000/9001)  │  │  │
│  │  └────────────────────┘  └────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Observability Stack                             │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  │  │
│  │  │  Prometheus        │  │  Grafana           │  │  │
│  │  │  (port 9090)       │  │  (port 3000)       │  │  │
│  │  └────────────────────┘  └────────────────────┘  │  │
│  │                                                  │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  │  │
│  │  │  Loki (Logs)       │  │  Tempo (Traces)    │  │  │
│  │  │  (port 3100)       │  │  (port 3200)       │  │  │
│  │  └────────────────────┘  └────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## Services inclus

### Keycloak 24

- **Port** : 8080 (http://localhost:8080)
- **Admin Console** : http://localhost:8080/admin
- **Realm** : plantogether
- **Default credentials** : admin/admin (configurable)

### PostgreSQL 16

- **Port** : 5432
- **Databases** : keycloak, plantogether, plantogether_test
- **Default user** : plantogether_user
- **Default password** : plantogether_password (configurable)

### RabbitMQ 3.13

- **Port AMQP** : 5672
- **Management UI** : http://localhost:15672
- **Default credentials** : guest/guest (configurable)

### Redis 7

- **Port** : 6379
- **Protocol** : RESP3 supporté
- **Pas d'authentification** par défaut (dev mode)

### MinIO

- **Port API** : 9000
- **Console** : http://localhost:9001
- **Default credentials** : minioadmin/minioadmin
- **Default buckets** : plantogether (for trip files/photos)

### Prometheus

- **Port** : 9090
- **URL** : http://localhost:9090
- **Scrape interval** : 15 secondes (configurable)

### Grafana

- **Port** : 3000
- **URL** : http://localhost:3000
- **Default credentials** : admin/admin
- **Data sources préconfigurées** : Prometheus, Loki, Tempo

### Loki

- **Port** : 3100
- **Agrégation des logs** depuis tous les services

### Tempo

- **Port** : 3200
- **Tracing distribué** pour le debugging

## Lancer en local

### Prérequis

- Docker 20.10+
- Docker Compose 2.0+
- Au moins 4 GB de RAM disponible
- Ports 3000-9001 disponibles

### Démarrage

```bash
# Cloner le repository
git clone <repo-url>
cd infra

# Lancer tous les services
docker compose up -d

# Vérifier que tous les services sont en cours d'exécution
docker compose ps

# Consulter les logs
docker compose logs -f

# Consulter les logs d'un service spécifique
docker compose logs -f keycloak
```

### Arrêt

```bash
# Arrêter tous les services
docker compose down

# Arrêter et supprimer les volumes (réinitialiser les données)
docker compose down -v

# Arrêter un service spécifique
docker compose stop keycloak
```

### Redémarrage

```bash
# Redémarrer tous les services
docker compose restart

# Redémarrer un service spécifique
docker compose restart redis
```

## Configuration

### docker-compose.yml - Services principaux

```yaml
version: '3.8'

services:
  # PostgreSQL 16
  postgres:
    image: postgres:16-alpine
    container_name: plantogether-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: postgres_root_password
      POSTGRES_USER: root
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U root" ]
      interval: 10s
      timeout: 5s
      retries: 5

  # Keycloak 24
  keycloak:
    image: keycloak/keycloak:24
    container_name: plantogether-keycloak
    ports:
      - "8080:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:-admin}
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak_user
      KC_DB_PASSWORD: ${KEYCLOAK_DB_PASSWORD:-keycloak_password}
      KC_PROXY: passthrough
      KC_HOSTNAME_STRICT: false
    depends_on:
      postgres:
        condition: service_healthy
    command:
      - start-dev
    volumes:
      - ./keycloak/realm-export.json:/opt/keycloak/data/import/realm.json
    profiles:
      - essential

  # RabbitMQ 3.13
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    container_name: plantogether-rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-guest}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./rabbitmq/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf
    healthcheck:
      test: rabbitmq-diagnostics ping
      interval: 10s
      timeout: 5s
      retries: 5
    profiles:
      - essential

  # Redis 7
  redis:
    image: redis:7-alpine
    container_name: plantogether-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: [ "CMD", "redis-cli", "ping" ]
      interval: 10s
      timeout: 5s
      retries: 5
    profiles:
      - essential

  # MinIO
  minio:
    image: minio/minio:latest
    container_name: plantogether-minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:-minioadmin}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:9000/minio/health/live" ]
      interval: 10s
      timeout: 5s
      retries: 5
    profiles:
      - essential

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: plantogether-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    profiles:
      - monitoring

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: plantogether-grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
      GF_USERS_ALLOW_SIGN_UP: false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    depends_on:
      - prometheus
    profiles:
      - monitoring

  # Loki
  loki:
    image: grafana/loki:latest
    container_name: plantogether-loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    profiles:
      - monitoring

  # Tempo
  tempo:
    image: grafana/tempo:latest
    container_name: plantogether-tempo
    ports:
      - "3200:3200"
      - "4317:4317"  # OTLP gRPC receiver
    volumes:
      - ./tempo/tempo.yml:/etc/tempo.yml
      - tempo_data:/var/tempo
    command: -config.file=/etc/tempo.yml
    profiles:
      - monitoring

volumes:
  postgres_data:
  rabbitmq_data:
  redis_data:
  minio_data:
  prometheus_data:
  grafana_data:
  loki_data:
  tempo_data:

networks:
  default:
    name: plantogether-network
```

## Sous-répertoires

### keycloak/

```
keycloak/
├── realm-export.json       # Export du realm plantogether
├── themes/                 # Thèmes personnalisés (optionnel)
└── providers/              # SPI personnalisés (plantogether-keycloak-spi JAR)
```

### postgres/

```
postgres/
├── init.sql               # Script d'initialisation des bases
└── backups/              # Sauvegardes PostgreSQL
```

### rabbitmq/

```
rabbitmq/
├── rabbitmq.conf         # Configuration RabbitMQ
└── definitions.json      # Exchanges, queues, bindings
```

### prometheus/

```
prometheus/
├── prometheus.yml        # Configuration Prometheus
└── rules.yml            # Alerting rules (optionnel)
```

### grafana/

```
grafana/
├── provisioning/
│   ├── datasources/     # Connexions aux sources de données
│   └── dashboards/      # Configuration des dashboards
└── dashboards/          # JSON des dashboards
```

### loki/

```
loki/
└── loki-config.yml     # Configuration Loki
```

### tempo/

```
tempo/
└── tempo.yml          # Configuration Tempo
```

## Commandes utiles

### Gestion des services

```bash
# Lancer uniquement les services essentiels
docker compose --profile essential up -d

# Lancer avec l'observabilité
docker compose --profile monitoring up -d

# Lancer tous les services
docker compose --profile essential --profile monitoring up -d

# Voir tous les services disponibles
docker compose config --services
```

### Accès aux services

```bash
# PostgreSQL CLI
docker compose exec postgres psql -U plantogether_user -d plantogether

# Redis CLI
docker compose exec redis redis-cli

# RabbitMQ shell
docker compose exec rabbitmq rabbitmq-diagnostics -q status

# MinIO CLI (mc)
docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker compose exec minio mc ls local/
```

### Logs et debugging

```bash
# Afficher les logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f keycloak

# Dernières 100 lignes
docker compose logs --tail=100 postgres

# Avec timestamps
docker compose logs -f --timestamps
```

### Nettoyage

```bash
# Nettoyer les images inutilisées
docker image prune -a

# Nettoyer les volumes orphelins
docker volume prune

# Nettoyer le système complet
docker system prune -a
```

## Santé des services

### Vérifier l'état

```bash
# Status de tous les services
docker compose ps

# Vérifier une connexion PostgreSQL
docker compose exec postgres pg_isready -U plantogether_user

# Vérifier RabbitMQ
curl http://localhost:15672/api/overview \
  -u guest:guest

# Vérifier Redis
redis-cli -h localhost ping

# Vérifier MinIO
curl http://localhost:9000/minio/health/live

# Vérifier Keycloak
curl http://localhost:8080/realms/plantogether
```

## Dépendances / Prérequis

### Docker Desktop

- Windows 10+ ou macOS 11+
- Au minimum 4 GB de RAM alloué
- 30 GB de stockage disque disponible

### Linux

```bash
# Installer Docker
sudo apt-get install docker.io docker-compose

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Vérifier l'installation
docker --version
docker compose version
```

## Configuration avancée

### Variables d'environnement (.env)

```bash
# Keycloak
KEYCLOAK_ADMIN_PASSWORD=your_admin_password
KEYCLOAK_DB_PASSWORD=your_db_password

# PostgreSQL
POSTGRES_PASSWORD=your_postgres_password

# RabbitMQ
RABBITMQ_PASSWORD=your_rabbitmq_password

# MinIO
MINIO_PASSWORD=your_minio_password

# Grafana
GRAFANA_PASSWORD=your_grafana_password
```

### Allocation de ressources

Pour les systèmes avec ressources limitées, éditer docker-compose.yml :

```yaml
services:
  keycloak:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## Troubleshooting

### Port déjà utilisé

```bash
# Trouver le service utilisant le port
lsof -i :8080

# Ou avec netstat
netstat -tlnp | grep 8080
```

### Services qui ne démarrent pas

```bash
# Vérifier les logs
docker compose logs -f <service_name>

# Redémarrer en mode debug
docker compose up <service_name>  # Sans -d
```

### Connexion à PostgreSQL échoue

```bash
# Vérifier que PostgreSQL est prêt
docker compose logs postgres | grep "database system is ready"

# Manuellement
docker compose exec postgres pg_isready -U root
```

### Espace disque insuffisant

```bash
# Nettoyer les images et volumes inutilisés
docker system prune -a --volumes

# Ou supprimer les volumes spécifiques
docker volume rm $(docker volume ls -q)
```

## Documentation supplémentaire

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html)
- [Redis Commands](https://redis.io/commands/)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
