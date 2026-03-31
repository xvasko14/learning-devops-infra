# DevOps Lab — Design Spec

**Dátum:** 2026-03-31
**Cieľ:** Hands-on learning projekt pre moderný cloud DevOps stack. Buduje sa inkrementálne, každý blok pridá vrstvu do funkčného prostredia. Výstup je portfólio-ready GitHub repo.

---

## Kontext

Michal má základ v Ansible, Kubernetes (K3s), Terraform (základy), Vagrant, Linux, Python, Go. Chýbajú mu Azure, Terraform pre Azure, GitHub Actions, PostgreSQL admin, Cassandra, RabbitMQ, Cloudflare. Pracuje 5-10 hodín týždenne s pomocou Claude Code.

---

## Projekt: `devops-lab`

GitHub repo s narastajúcou infraštruktúrou. Každý blok je samostatná vrstva ktorá stojí na predošlej.

### Aplikácia

Python Flask app — minimálny kód, len toľko aby sme mali čo deploynúť a integrovať s databázami/messaging.

Endpointy:
- `GET /health` — liveness check
- `POST /messages` — pošle správu do RabbitMQ
- `GET /data` — číta z Cassandra / PostgreSQL

### Repo štruktúra

```
devops-lab/
├── app/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── terraform/
│   ├── modules/            # reusable moduly (container_app, vnet, keyvault, ...)
│   └── environments/
│       ├── dev/
│       └── prod/
├── ansible/
│   ├── inventory/
│   └── playbooks/
├── kubernetes/
│   ├── manifests/
│   └── helm/
├── .github/
│   └── workflows/          # CI/CD pipelines
└── docs/
```

---

## Learning plán — 4 bloky / ~12 týždňov

### Blok 1 — Cloud Infra (týždeň 1-3)

**Cieľ:** Rozumieť Azure ekosystému a mať celú infra ako kód v Terraform.

| Týždeň | Téma | Výstup |
|--------|------|--------|
| 1 | Azure CLI + Container Apps manuálne | Flask app beží na Azure Container Apps |
| 2 | Terraform — základy Azure provider | Infra z týždňa 1 prepísaná do Terraform |
| 3 | Terraform — moduly + remote state | Reusable modul pre Container App, state v Azure Blob Storage |

**Koncepty:**
- Azure: Resource Groups, Container App Environments, VNets, NSGs, ACR, ACI
- Terraform: provider, resource, variable, output, module, remote backend
- Docker: build, tag, push do Azure Container Registry

---

### Blok 2 — Automation & Orchestration (týždeň 4-6)

**Cieľ:** Automatizovať deployment a rozumieť container orchestrácii.

| Týždeň | Téma | Výstup |
|--------|------|--------|
| 4 | Ansible — VM provisioning + config management | Ansible playbook provisionuje Ubuntu VM a deployuje app |
| 5 | GitHub Actions CI/CD | Push do main → automatický build + deploy na Azure |
| 6 | Kubernetes (AKS alebo K3s) + Helm | App beží v K8s clustri, deployovaná cez Helm chart |

**Koncepty:**
- Ansible: inventory, playbooks, roles, idempotencia, Ansible Vault
- GitHub Actions: workflows, jobs, steps, secrets, environments, matrix builds
- Kubernetes: Deployments, Services, Ingress, ConfigMaps, Secrets, HPA
- Helm: chart štruktúra, values.yaml, templating

---

### Blok 3 — Data & Messaging (týždeň 7-9)

**Cieľ:** Spravovať produkčné databázy a messaging systémy.

| Týždeň | Téma | Výstup |
|--------|------|--------|
| 7 | PostgreSQL admin | 3-node replication cluster, PITR backups, pg_dump, monitoring |
| 8 | Apache Cassandra cluster | 3-node lokálny cluster, keyspaces, replication factor, nodetool |
| 9 | RabbitMQ cluster | 3-node cluster, exchanges, queues, dead letter, management UI |

**Koncepty:**
- PostgreSQL: streaming replication (primary/replica), pg_basebackup, PITR, pg_stat_*, slow query log
- Cassandra: multi-DC replication, SAI indexes, nodetool repair/status/ring, compaction
- RabbitMQ: AMQP, exchanges (direct/fanout/topic), quorum queues, shovel plugin

---

### Blok 4 — Security, Networking & Observability (týždeň 10-12)

**Cieľ:** Produkčná bezpečnosť, networking a monitoring.

| Týždeň | Téma | Výstup |
|--------|------|--------|
| 10 | Azure Key Vault + managed identity + RBAC | Žiadne secrets v kóde, rotácia, least privilege |
| 11 | Cloudflare — DNS, WAF, Zero Trust | App za Cloudflare, WAF rules, geo-steering |
| 12 | Azure Monitor + Application Insights + DR | Dashboardy, alerting, backup/restore test, RTO/RPO |

**Koncepty:**
- Key Vault: secrets, managed identities, access policies, RBAC, secret rotation
- Cloudflare: DNS, WAF rules, Page Rules, Zero Trust tunnel, Workers basics
- Observability: metriky, logy, traces, SLI/SLO, alerting rules
- DR: backup stratégia, restore testing, RTO/RPO dokumentácia

---

## Pracovný postup

1. Každý týždeň = jedna téma, jeden funkčný výstup
2. Claude Code napíše kód + vysvetlí čo robí a prečo
3. Michal spustí, vidí výsledok, pýta sa na nejasnosti
4. Po fungujúcom výsledku: commit + push do GitHub
5. Monitoring sa pridáva postupne od Bloku 2, nie len na konci

---

## Úspech

Na konci 12 týždňov:
- GitHub repo s kompletnou infraštruktúrou od Container Apps po Kubernetes, Cassandra, RabbitMQ, Cloudflare
- Každá vrstva je zdokumentovaná a fungujúca
- Použiteľné ako portfólio na pohovory pre Senior DevOps pozície
