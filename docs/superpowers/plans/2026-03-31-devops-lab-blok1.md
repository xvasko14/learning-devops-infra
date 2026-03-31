# DevOps Lab — Blok 1: Cloud Infra Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Postaviť Python Flask app, deploynúť ju manuálne na Azure Container Apps, potom celú infraštruktúru prepísať do Terraform s reusable modulmi a remote state.

**Architecture:** Flask app beží ako Docker container v Azure Container Apps. Infra je definovaná v Terraform — Resource Group, VNet, Container App Environment, Container App, ACR. State je uložený v Azure Blob Storage. Moduly sú reusable (container_app, vnet).

**Tech Stack:** Python 3.12, Flask, Docker, Azure CLI, Azure Container Apps, Azure Container Registry, Terraform 1.x (azurerm provider)

---

## Súbory ktoré vzniknú

```
devops-lab/
├── app/
│   ├── main.py                              # Flask app
│   ├── Dockerfile                           # Multi-stage build
│   └── requirements.txt
├── terraform/
│   ├── modules/
│   │   ├── container_app/
│   │   │   ├── main.tf                      # Container App + Environment
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── vnet/
│   │       ├── main.tf                      # VNet + Subnet
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       └── dev/
│           ├── main.tf                      # Root module — volá submoduly
│           ├── variables.tf
│           ├── outputs.tf
│           └── backend.tf                   # Remote state v Azure Blob
└── docs/
    └── blok1-poznamky.md                    # Tvoje poznámky čo si sa naučil
```

---

## Task 1: Repo setup + Flask app

**Files:**
- Create: `app/main.py`
- Create: `app/requirements.txt`
- Create: `app/Dockerfile`

- [ ] **Krok 1: Inicializuj GitHub repo**

Choď na GitHub.com → New repository → názov `devops-lab` → Public → bez README (pridáme sami).

```bash
mkdir ~/devops-lab && cd ~/devops-lab
git init
git remote add origin git@github.com:<TVOJ_USERNAME>/devops-lab.git
```

- [ ] **Krok 2: Vytvor Flask app**

`app/requirements.txt`:
```
flask==3.1.0
gunicorn==23.0.0
```

`app/main.py`:
```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "devops-lab"})

@app.route("/")
def index():
    return jsonify({"message": "DevOps Lab running"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

- [ ] **Krok 3: Vytvor Dockerfile**

`app/Dockerfile`:
```dockerfile
# Build stage
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/packages -r requirements.txt

# Runtime stage
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /app/packages /app/packages
COPY main.py .
ENV PYTHONPATH=/app/packages
EXPOSE 8080
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
```

- [ ] **Krok 4: Otestuj lokálne**

```bash
cd ~/devops-lab
docker build -t devops-lab:local ./app
docker run -p 8080:8080 devops-lab:local
```

V druhom terminali:
```bash
curl http://localhost:8080/health
```
Očakávaný output: `{"service":"devops-lab","status":"ok"}`

- [ ] **Krok 5: Zastav container a commitni**

```bash
# Ctrl+C v prvom terminali
git add app/
git commit -m "feat: add Flask app with health endpoint"
git push -u origin main
```

---

## Task 2: Azure CLI setup + manuálny deploy

**Predpoklad:** Máš Azure account. Neinštaluj nič čo už máš.

- [ ] **Krok 1: Nainštaluj Azure CLI (ak nemáš)**

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az version
```
Očakávaný output: `"azure-cli": "2.x.x"`

- [ ] **Krok 2: Prihlás sa do Azure**

```bash
az login
az account show
```
Skontroluj že vidíš správny subscription.

- [ ] **Krok 3: Vytvor Resource Group a ACR**

```bash
# Nastav premenné (zmeň na svoje)
RESOURCE_GROUP="devops-lab-rg"
LOCATION="westeurope"
ACR_NAME="devopslabacr$(openssl rand -hex 4)"   # musí byť globally unique

az group create --name $RESOURCE_GROUP --location $LOCATION

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

Očakávaný output: JSON s `"provisioningState": "Succeeded"`

- [ ] **Krok 4: Push Docker image do ACR**

```bash
# Prihlás sa do ACR
az acr login --name $ACR_NAME

# Tag a push
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
docker build -t $ACR_LOGIN_SERVER/devops-lab:v1 ./app
docker push $ACR_LOGIN_SERVER/devops-lab:v1
```

Overenie:
```bash
az acr repository list --name $ACR_NAME -o table
```
Očakávaný output: `devops-lab` v zozname.

- [ ] **Krok 5: Vytvor Container App**

```bash
# Nainštaluj Container Apps extension
az extension add --name containerapp --upgrade

az containerapp env create \
  --name devops-lab-env \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

az containerapp create \
  --name devops-lab-app \
  --resource-group $RESOURCE_GROUP \
  --environment devops-lab-env \
  --image $ACR_LOGIN_SERVER/devops-lab:v1 \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_NAME \
  --registry-password $ACR_PASSWORD \
  --target-port 8080 \
  --ingress external \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 3
```

- [ ] **Krok 6: Otestuj živú app**

```bash
APP_URL=$(az containerapp show \
  --name devops-lab-app \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)

curl https://$APP_URL/health
```
Očakávaný output: `{"service":"devops-lab","status":"ok"}`

**Ulož si $ACR_NAME a $APP_URL — budeš ich potrebovať.**

- [ ] **Krok 7: Zapíš čo si sa naučil**

Vytvor `docs/blok1-poznamky.md` a napíš vlastnými slovami:
- Čo je Resource Group
- Čo je ACR a prečo ho potrebujeme
- Čo je Container App Environment vs Container App
- Čo robí `--ingress external`

*(Toto nie je formalita — pomôže ti to na pohovore.)*

- [ ] **Krok 8: Commitni**

```bash
git add docs/
git commit -m "docs: add blok1 notes on Azure manual deploy"
git push
```

---

## Task 3: Terraform — základy Azure

**Čo sa naučíš:** provider, resource, variable, output, locals, data sources.

**Files:**
- Create: `terraform/environments/dev/main.tf`
- Create: `terraform/environments/dev/variables.tf`
- Create: `terraform/environments/dev/outputs.tf`

- [ ] **Krok 1: Nainštaluj Terraform**

```bash
# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

terraform version
```
Očakávaný output: `Terraform v1.x.x`

- [ ] **Krok 2: Vytvor Terraform pre dev environment**

`terraform/environments/dev/variables.tf`:
```hcl
variable "resource_group_name" {
  type        = string
  description = "Názov Azure Resource Group"
}

variable "location" {
  type        = string
  description = "Azure región"
  default     = "westeurope"
}

variable "acr_name" {
  type        = string
  description = "Globálne unikátny názov Azure Container Registry"
}

variable "container_image" {
  type        = string
  description = "Full image URL vrátane tagu (napr. myacr.azurecr.io/devops-lab:v1)"
}

variable "acr_username" {
  type        = string
  description = "ACR admin username"
}

variable "acr_password" {
  type        = string
  description = "ACR admin password"
  sensitive   = true
}
```

`terraform/environments/dev/main.tf`:
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  required_version = ">= 1.5"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_app_environment" "main" {
  name                = "${var.resource_group_name}-env"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_app" "app" {
  name                         = "devops-lab-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = var.acr_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = var.acr_password
  }

  template {
    container {
      name   = "devops-lab"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
    }
    min_replicas = 1
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
```

`terraform/environments/dev/outputs.tf`:
```hcl
output "app_url" {
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
  description = "URL nasadenej aplikácie"
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "ACR login server pre docker push"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
}
```

- [ ] **Krok 3: Vytvor terraform.tfvars (NIKDY nekomitnúť!)**

```bash
cat > terraform/environments/dev/terraform.tfvars <<EOF
resource_group_name = "devops-lab-rg-tf"
location            = "westeurope"
acr_name            = "devopslabacrtf$(openssl rand -hex 3)"
container_image     = "PLACEHOLDER_zmenime_neskor"
acr_username        = "PLACEHOLDER"
acr_password        = "PLACEHOLDER"
EOF
```

Pridaj do `.gitignore`:
```bash
cat >> .gitignore <<EOF
*.tfvars
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
EOF
```

```bash
git add .gitignore
git commit -m "chore: add gitignore for terraform sensitive files"
```

- [ ] **Krok 4: Init a validate**

```bash
cd terraform/environments/dev
terraform init
terraform validate
```
Očakávaný output: `Success! The configuration is valid.`

- [ ] **Krok 5: Plan — uvidíš čo Terraform chce vytvoriť**

```bash
terraform plan
```
Očakávaný output: `Plan: 4 to add, 0 to change, 0 to destroy.`

*(Container App si nainštaluješ neskôr — teraz stačí rozumieť outputu.)*

- [ ] **Krok 6: Apply — nasaď infraštruktúru**

Najprv aktualizuj `terraform.tfvars` so správnymi hodnotami z Task 2 (ACR name, password).

```bash
# Získaj ACR password
az acr credential show --name <TVOJ_ACR_NAME> --query passwords[0].value -o tsv
```

Aktualizuj `terraform.tfvars` a potom:
```bash
terraform apply
```
Napíš `yes` keď sa spýta.

Očakávaný output:
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:
app_url = "https://devops-lab-app.xyz.westeurope.azurecontainerapps.io"
```

- [ ] **Krok 7: Otestuj**

```bash
APP_URL=$(terraform output -raw app_url)
curl $APP_URL/health
```
Očakávaný output: `{"service":"devops-lab","status":"ok"}`

- [ ] **Krok 8: Commitni Terraform kód**

```bash
cd ~/devops-lab
git add terraform/environments/dev/*.tf
git commit -m "feat: add terraform for dev environment (manual state)"
git push
```

---

## Task 4: Terraform — Remote State v Azure Blob Storage

**Prečo:** Lokálny tfstate nesmie byť v git (obsahuje secrets). Remote state v Azure Blob je zdieľaný, zamknutý pri apply, bezpečný.

**Files:**
- Create: `terraform/environments/dev/backend.tf`
- Modify: `terraform/environments/dev/main.tf`

- [ ] **Krok 1: Vytvor Storage Account pre state**

```bash
STORAGE_ACCOUNT="devopslabstate$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"

az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group devops-lab-rg \
  --location westeurope \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT
```

Ulož si `$STORAGE_ACCOUNT` — budeš ho potrebovať.

- [ ] **Krok 2: Vytvor backend.tf**

`terraform/environments/dev/backend.tf`:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "devops-lab-rg"
    storage_account_name = "ZMEN_NA_TVOJ_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
  }
}
```

Zmeň `storage_account_name` na tvoju hodnotu z predošlého kroku.

- [ ] **Krok 3: Migruj state do remote**

```bash
cd terraform/environments/dev
terraform init -migrate-state
```

Odpoveď `yes` keď sa spýta či chceš migrovať.

Očakávaný output:
```
Successfully configured the backend "azurerm"!
Terraform will automatically use this backend unless the backend
configuration changes.
```

- [ ] **Krok 4: Overenie**

```bash
# State je teraz v Azure, nie lokálne
ls -la terraform/environments/dev/
# terraform.tfstate by mal byť prázdny alebo chýbať

# Terraform stále funguje
terraform plan
```
Očakávaný output: `No changes. Your infrastructure matches the configuration.`

- [ ] **Krok 5: Commitni**

```bash
cd ~/devops-lab
git add terraform/environments/dev/backend.tf
git add terraform/environments/dev/main.tf  # ak si menil
git commit -m "feat: migrate terraform state to azure blob storage"
git push
```

---

## Task 5: Terraform — Reusable moduly

**Prečo:** Moduly = reusable kód. Keď budeš mať dev + prod, nebudeš kopírovať HCL.

**Files:**
- Create: `terraform/modules/container_app/main.tf`
- Create: `terraform/modules/container_app/variables.tf`
- Create: `terraform/modules/container_app/outputs.tf`
- Create: `terraform/modules/vnet/main.tf`
- Create: `terraform/modules/vnet/variables.tf`
- Create: `terraform/modules/vnet/outputs.tf`
- Modify: `terraform/environments/dev/main.tf`

- [ ] **Krok 1: VNet modul**

`terraform/modules/vnet/variables.tf`:
```hcl
variable "name" {
  type        = string
  description = "Názov VNet"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "CIDR blok pre VNet"
}

variable "subnet_address_prefix" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR blok pre Container Apps subnet"
}
```

`terraform/modules/vnet/main.tf`:
```hcl
resource "azurerm_virtual_network" "main" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
}

resource "azurerm_subnet" "container_apps" {
  name                 = "${var.name}-container-apps-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]

  delegation {
    name = "container-apps"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
```

`terraform/modules/vnet/outputs.tf`:
```hcl
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_id" {
  value = azurerm_subnet.container_apps.id
}
```

- [ ] **Krok 2: Container App modul**

`terraform/modules/container_app/variables.tf`:
```hcl
variable "app_name" {
  type        = string
  description = "Názov Container App"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "Subnet ID pre Container App Environment"
}

variable "container_image" {
  type        = string
  description = "Full image URL (napr. myacr.azurecr.io/app:v1)"
}

variable "acr_login_server" {
  type = string
}

variable "acr_username" {
  type = string
}

variable "acr_password" {
  type      = string
  sensitive = true
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 3
}
```

`terraform/modules/container_app/main.tf`:
```hcl
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  infrastructure_subnet_id   = var.infrastructure_subnet_id
}

resource "azurerm_container_app" "main" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  registry {
    server               = var.acr_login_server
    username             = var.acr_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = var.acr_password
  }

  template {
    container {
      name   = var.app_name
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory
    }
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    external_enabled = true
    target_port      = var.target_port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
```

`terraform/modules/container_app/outputs.tf`:
```hcl
output "app_fqdn" {
  value       = azurerm_container_app.main.ingress[0].fqdn
  description = "FQDN aplikácie (bez https://)"
}

output "app_url" {
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "environment_id" {
  value = azurerm_container_app_environment.main.id
}
```

- [ ] **Krok 3: Prepíš dev/main.tf aby používal moduly**

`terraform/environments/dev/main.tf` (plná náhrada):
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  required_version = ">= 1.5"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

module "vnet" {
  source = "../../modules/vnet"

  name                = "${var.resource_group_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

module "app" {
  source = "../../modules/container_app"

  app_name                 = "devops-lab-app"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  infrastructure_subnet_id = module.vnet.subnet_id
  container_image          = var.container_image
  acr_login_server         = azurerm_container_registry.main.login_server
  acr_username             = var.acr_username
  acr_password             = var.acr_password
}
```

- [ ] **Krok 4: Init (nový modul) + validate + plan**

```bash
cd terraform/environments/dev
terraform init    # stiahne nové moduly
terraform validate
terraform plan
```

Očakávaný output: plán ukáže **destroy + create** pre `azurerm_container_app_environment` — je to normálne. Azure nedovolí zmeniť VNet na existujúcom environment, takže Terraform ho zmaže a vytvorí nový. App bude chvíľu nedostupná (2-5 min).

- [ ] **Krok 5: Apply**

```bash
terraform apply
```

Napíš `yes`. Terraform zmaže starý environment a vytvorí nový s VNet. Toto je dôležitá lekcia: niektoré Azure resources sú **immutable** — po vytvorení sa nedajú meniť, len zahodiť a vytvoriť odznova. Terraform to robí automaticky.

- [ ] **Krok 6: Otestuj že app stále beží**

```bash
APP_URL=$(terraform output -raw app_url)
curl $APP_URL/health
```
Očakávaný output: `{"service":"devops-lab","status":"ok"}`

- [ ] **Krok 7: Commitni**

```bash
cd ~/devops-lab
git add terraform/modules/ terraform/environments/
git commit -m "feat: refactor terraform into reusable modules (vnet, container_app)"
git push
```

---

## Blok 1 — Záverečné overenie

Po dokončení všetkých taskov over:

- [ ] `curl $APP_URL/health` vracia `{"status":"ok"}`
- [ ] `terraform plan` hovorí `No changes.`
- [ ] `terraform state list` ukazuje všetky resources
- [ ] GitHub repo má commity pre každý task
- [ ] `docs/blok1-poznamky.md` existuje a je vyplnený

---

## Čo nasleduje

**Blok 2** (samostatný plán): Ansible → GitHub Actions CI/CD → Kubernetes + Helm

Pred začatím Bloku 2: zmaž manuálne vytvorené resources z Tasku 2 (`az group delete --name devops-lab-rg`) — budeš mať len Terraform-managed infra.

---

## Poznámky pre debugovanie

**"Container App Environment provisioning trvá dlho"** — normálne, môže trvať 5-10 minút. Čakaj.

**"ACR admin credentials"** — v produkcii sa používajú Managed Identities (naučíme v Bloku 4). Teraz admin credentials stačia.

**"terraform init -migrate-state" pýta yes/no** — vždy skontroluj čo migruješ pred yes.

**"No changes" po zmene kódu** — skontroluj či si uložil súbor a či si v správnom adresári.
