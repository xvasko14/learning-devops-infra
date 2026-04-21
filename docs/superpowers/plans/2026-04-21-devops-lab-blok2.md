# DevOps Lab — Blok 2: Automation & Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatizovať deployment Flask app a nasadiť ju do Kubernetes clustra cez Ansible, GitHub Actions a Helm.

**Architecture:** Azure VM (vytvorená Terraformom) je konfigurovaná Ansible playbookom. GitHub Actions automaticky builduje a deployuje pri pushu do main. K3s (lightweight Kubernetes) beží na VM, app je deployovaná cez Helm chart.

**Tech Stack:** Ansible, GitHub Actions, K3s, Helm, Terraform (azurerm ~3.100), Azure CLI

---

## Súbory ktoré existujú (vytvorené v blok2-automation branch)

```
terraform/modules/vm/          ← nový Terraform modul pre Azure VM
  main.tf                      ← public IP, NSG, NIC, Linux VM
  variables.tf
  outputs.tf
terraform/modules/vnet/        ← rozšírený o vm subnet (10.0.2.0/24)
  main.tf
  outputs.tf
terraform/environments/dev/    ← rozšírený o module "vm" a ssh_public_key variable
  main.tf
  variables.tf
  outputs.tf
ansible/inventory/
  hosts.yml                    ← doplníš IP adresu po terraform apply
ansible/playbooks/
  configure_vm.yml             ← Docker install + app deploy
  install_k3s.yml              ← K3s install + ACR secret
.github/workflows/
  ci.yml                       ← CI/CD pipeline
kubernetes/helm/devops-lab/
  Chart.yaml
  values.yaml
  templates/deployment.yaml
  templates/service.yaml
```

---

## Task 6: Ansible — VM provisioning + config management

### Čo je Ansible?

Ansible je nástroj na **konfiguráciu serverov cez SSH**. Bez agenta — neinštaluješ nič na managed node. Z tvojho počítača (control node) Ansible:
1. Otvorí SSH spojenie s VM
2. Vykoná tasks (inštalácia balíkov, spustenie kontajnerov, ...)
3. Spojenie zatvorí

Výsledok je rovnaký ako keby si to robil manuálne cez SSH — ale automaticky a opakovateľne.

**Terraform vs Ansible:**
| | Terraform | Ansible |
|---|---|---|
| Čo robí | Vytvorí VM v Azure | Nakonfiguruje VM čo beží |
| Ako komunikuje | Azure REST API | SSH |
| Prístup | Deklaratívny (state) | Procedurálny (playbook) |
| Analógia | Postaví budovu | Zariadí interiér |

**Idempotencia:** `apt: state: present` = "Docker musí byť nainštalovaný". Ak už je, Ansible neurobí nič. Spusti playbook 10× — rovnaký výsledok. Shell skript s `apt install` by každý raz niečo robil.

**Files:**
- Create: `~/.ssh/devops-lab` (SSH kľúč — lokálne, nie v gite)
- Modify: `terraform.tfvars` (pridaj ssh_public_key — v Cloud Shelli, nie v gite)
- Modify: `ansible/inventory/hosts.yml` (doplníš IP)

- [ ] **Krok 1: Vygeneruj SSH kľúč**

Na lokálnom počítači (nie Cloud Shell):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops-lab -C "devops-lab"
cat ~/.ssh/devops-lab.pub
```
Skopíruj výstup — budeš ho potrebovať v ďalšom kroku.

- [ ] **Krok 2: Pridaj SSH kľúč do terraform.tfvars**

V Cloud Shelli — pridaj do `terraform/environments/dev/terraform.tfvars`:
```hcl
ssh_public_key = "ssh-ed25519 AAAA...  devops-lab"
```
Zmeň `AAAA...` na skutočný obsah z predošlého kroku.

- [ ] **Krok 3: Terraform init + plan**

```bash
cd terraform/environments/dev
terraform init    # stiahne nový vm modul
terraform plan
```

Uvidíš nové resources:
```
+ module.vm.azurerm_public_ip.main
+ module.vm.azurerm_network_security_group.main
+ module.vm.azurerm_network_interface.main
+ module.vm.azurerm_network_interface_security_group_association.main
+ module.vm.azurerm_linux_virtual_machine.main
+ module.vnet.azurerm_subnet.vm
Plan: 6 to add, 0 to change, 0 to destroy.
```

`azurerm_network_security_group` = firewall na úrovni NIC. Má pravidlá pre SSH (22), app (8080) a K3s NodePort (30000-32767).

- [ ] **Krok 4: Terraform apply**

```bash
terraform apply
```
Napíš `yes`. Trvá ~2-3 minúty.

- [ ] **Krok 5: Ulož VM IP**

```bash
terraform output vm_public_ip
```
Ulož si túto IP — budeš ju potrebovať viackrát.

- [ ] **Krok 6: Overenie SSH**

Na lokálnom počítači (nie Cloud Shell):
```bash
ssh -i ~/.ssh/devops-lab azureuser@<VM_IP>
```
Očakávaný output: Ubuntu prompt `azureuser@devops-lab-vm:~$`

Ak to funguje, opusti VM:
```bash
exit
```

- [ ] **Krok 7: Nainštaluj Ansible**

Na lokálnom počítači:
```bash
sudo apt update && sudo apt install ansible -y
ansible --version
# ansible [core 2.x.x]

ansible-galaxy collection install community.docker
# Installing community.docker...
```

`community.docker` collection obsahuje moduly `docker_login`, `docker_image`, `docker_container` ktoré playbook používa. Bez nej playbook zlyhá.

- [ ] **Krok 8: Uprav inventory**

Otvor `ansible/inventory/hosts.yml`:
```yaml
all:
  hosts:
    devops-vm:
      ansible_host: CHANGE_ME   # ← zmeň na VM IP z Kroku 5
      ansible_user: azureuser
      ansible_ssh_private_key_file: ~/.ssh/devops-lab
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

Zmeň `CHANGE_ME` na tvoju VM IP.

- [ ] **Krok 9: Otestuj konektivitu**

```bash
ansible all -i ansible/inventory/hosts.yml -m ping
```
Očakávaný output:
```
devops-vm | SUCCESS => {
    "ping": "pong"
}
```

Ak `ping` funguje, Ansible sa vie pripojiť k VM.

- [ ] **Krok 10: Získaj ACR credentials**

```bash
# V Cloud Shelli
az acr credential show --name devopslabacrtf01 --query passwords[0].value -o tsv
```
Ulož si heslo — budeš ho potrebovať v ďalšom kroku.

- [ ] **Krok 11: Spusti Ansible playbook**

Pozri si `ansible/playbooks/configure_vm.yml` — playbook robí toto v poradí:
1. `apt install docker.io docker-compose curl` — nainštaluje Docker
2. `service docker started` — spustí Docker daemon
3. Pridá `azureuser` do `docker` skupiny (môže používať docker bez sudo)
4. `docker_login` na ACR (no_log:true skryje credentials v output)
5. `docker_image pull` — stiahne image z ACR
6. `docker_container run` — spustí kontajner s `restart_policy: always`

Spusti playbook:
```bash
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/configure_vm.yml \
  -e "acr_username=devopslabacrtf01" \
  -e "acr_password=<ACR_HESLO>"
```

Očakávaný output — každý task hlási `ok` alebo `changed`:
```
PLAY RECAP
devops-vm : ok=6  changed=5  unreachable=0  failed=0
```

- [ ] **Krok 12: Overenie**

```bash
curl http://<VM_IP>:8080/health
# {"service":"devops-lab","status":"ok"}
```

App beží na VM v Docker kontajneri, nakonfigurovaná Ansible playbookom.

- [ ] **Krok 13: Commitni zmenu v inventory**

```bash
git add ansible/inventory/hosts.yml
git commit -m "feat: configure ansible inventory with vm ip"
```

---

## Task 7: GitHub Actions CI/CD

### Čo je CI/CD?

- **CI (Continuous Integration):** Každý push automaticky builduje a testuje kód
- **CD (Continuous Deployment):** Po úspešnom CI sa kód automaticky nasadí

**GitHub Actions** = CI/CD systém vstavaný do GitHubu. Definuješ workflow v YAML súbore v `.github/workflows/`. Každý push spustí workflow automaticky.

Pozri si `.github/workflows/ci.yml` — workflow robí toto:
1. `actions/checkout` — stiahne kód
2. `azure/login` — prihlási sa do Azure cez Service Principal
3. `az acr build` — zbuilduje image a pushne do ACR (tagger commitom SHA)
4. `az containerapp update` — nasadí nový image do Container App
5. `curl /health` — overí že app beží

**Prečo `github.sha` ako tag?** `devops-lab:abc1234` vždy ukáže z ktorého commitu pochádza. `latest` by si pamätal len posledný — rollback by bol ťažký.

**Files:**
- `.github/workflows/ci.yml` — existuje, netreba meniť
- GitHub repo Settings → Secrets — tu pridáš credentials

- [ ] **Krok 1: Vytvor Service Principal**

Service Principal = "robot konto" pre GitHub Actions s obmedzenými permissions.

V Cloud Shelli:
```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "github-actions-devops-lab" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/devops-lab-rg-tf \
  --sdk-auth
```

Skopíruj celý JSON output — budeš ho potrebovať.

**Čo robí `--role contributor`?** SP môže čítať a meniť resources v resource group, ale nemôže meniť permissions (to je `owner` role).

- [ ] **Krok 2: Pridaj GitHub Secrets**

Choď na GitHub → tvoj repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Pridaj tieto secrets:

| Secret name | Hodnota |
|---|---|
| `AZURE_CREDENTIALS` | celý JSON z Kroku 1 |
| `ACR_LOGIN_SERVER` | `devopslabacrtf01.azurecr.io` |
| `ACR_USERNAME` | `devopslabacrtf01` |
| `ACR_PASSWORD` | heslo z `az acr credential show` |

**Prečo secrets?** Sú šifrované v GitHub, nevypíšu sa v logoch ani v YAML súbore. Každý kto má prístup k repo vidí že secret existuje, ale nie jeho hodnotu.

- [ ] **Krok 3: Otestuj pipeline**

Urob malú zmenu v `app/main.py` — napríklad zmeň verziu v health response:
```python
return jsonify({"status": "ok", "service": "devops-lab", "version": "2"})
```

```bash
git add app/main.py
git commit -m "test: trigger ci pipeline"
git push
```

Sleduj priebeh na GitHub → **Actions** tab. Uvidíš bežiaci workflow.

- [ ] **Krok 4: Sleduj kroky workflow**

V Actions tab klikni na bežiaci workflow. Uvidíš jednotlivé steps:
- `Log in to Azure` — prihlasuje sa cez AZURE_CREDENTIALS secret
- `Build and push image to ACR` — `az acr build` trvá ~2 min
- `Deploy new image to Container App` — `az containerapp update`
- `Verify deployment` — čaká 30s, potom `curl /health`

- [ ] **Krok 5: Overenie**

Po úspešnom workflow:
```bash
curl https://devops-lab-app.thankfulisland-3f165886.westeurope.azurecontainerapps.io/health
# {"service":"devops-lab","status":"ok","version":"2"}
```

- [ ] **Krok 6: Vráť zmenu v app/main.py**

```python
return jsonify({"status": "ok", "service": "devops-lab"})
```

```bash
git add app/main.py
git commit -m "revert: remove test version field"
git push
```

---

## Task 8: Kubernetes (K3s) + Helm

### Čo je Kubernetes?

**Kubernetes** (K8s) = orchestrátor kontajnerov. Rieši problémy ktoré Docker sám nevyrieši:
- Chceš 3 repliky kontajnera — Docker to neumie automaticky
- Kontajner crashne o 3:00 ráno — K8s ho reštartuje
- Chceš update bez downtime — K8s robí rolling update (staré pody vypína, nové zapína postupne)

**K3s** = lightweight Kubernetes. Jedna binárka (~70MB), beží na 1 vCPU / 512MB RAM. Rovnaké `kubectl` príkazy a Helm charts ako plný K8s. Ideálne pre learning a edge.

**Základné K8s objekty:**
| Objekt | Čo je |
|---|---|
| Pod | Jeden bežiaci kontajner (alebo viac) |
| Deployment | "Chcem 2 repliky tohto podu" — K8s to udržiava |
| Service | Sieťový endpoint pre skupinu podov (load balancer) |
| NodePort | Typ Service — dostupná cez port na VM (napr. 30080) |

**Helm** = package manager pre Kubernetes. Namiesto `kubectl apply -f deployment.yaml -f service.yaml` napíšeš `helm install devops-lab`. Chart = balík = šablóny YAML súborov s parametrami (`values.yaml`).

Pozri si `kubernetes/helm/devops-lab/` — štruktúra:
- `Chart.yaml` — metadata (meno, verzia)
- `values.yaml` — default hodnoty (image, repliky, port)
- `templates/deployment.yaml` — Deployment šablóna s `{{ .Values.X }}` placeholdermi
- `templates/service.yaml` — NodePort Service na porte 30080

**Files:**
- `ansible/playbooks/install_k3s.yml` — existuje
- `kubernetes/helm/devops-lab/` — existuje

- [ ] **Krok 1: Nainštaluj K3s cez Ansible**

Pozri si `ansible/playbooks/install_k3s.yml` — robí toto:
1. Nainštaluje K3s cez official inštalačný skript (idempotentné: ak `/usr/local/bin/k3s` existuje, preskočí)
2. Čaká kým je K3s ready (`k3s kubectl get nodes` vráti 0)
3. Stiahne kubeconfig na `localhost:/tmp/k3s-kubeconfig.yaml`
4. Vytvorí K8s secret s ACR credentials (dry-run+apply pattern = idempotentné)

Spusti:
```bash
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/install_k3s.yml \
  -e "acr_username=devopslabacrtf01" \
  -e "acr_password=<ACR_HESLO>"
```

Trvá ~2 minúty. K3s sa nainštaluje a spustí.

- [ ] **Krok 2: Nakonfiguruj kubectl**

Ansible stiahol kubeconfig do `/tmp/k3s-kubeconfig.yaml` ale ukazuje na `127.0.0.1` (lokálny server). Zmeň na VM IP:
```bash
sed -i 's/127.0.0.1/<VM_IP>/g' /tmp/k3s-kubeconfig.yaml
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
```

**Čo je kubeconfig?** Súbor s credentials a URL K8s API servera. `kubectl` ho číta aby vedelo kde je cluster a ako sa autentifikovať.

- [ ] **Krok 3: Overenie kubectl**

```bash
kubectl get nodes
```
Očakávaný output:
```
NAME             STATUS   ROLES                  AGE
devops-lab-vm   Ready    control-plane,master   2m
```

`Ready` = K3s beží a je pripravený prijímať workloady.

- [ ] **Krok 4: Nainštaluj Helm**

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
# version.BuildInfo{Version:"v3.x.x"...}
```

- [ ] **Krok 5: Nasaď app cez Helm**

```bash
helm install devops-lab kubernetes/helm/devops-lab/
```

Helm vezme šablóny z `templates/`, dosadí hodnoty z `values.yaml` a aplikuje do K3s.

Sleduj čo sa deje:
```bash
kubectl get pods -w
```
Očakávaný output (po ~30 sekundách):
```
NAME                          READY   STATUS    RESTARTS
devops-lab-xxx-yyy   1/1     Running   0
devops-lab-aaa-bbb   1/1     Running   0
```

2 pody bežia (podľa `replicaCount: 2` v values.yaml).

- [ ] **Krok 6: Overenie**

```bash
curl http://<VM_IP>:30080/health
# {"service":"devops-lab","status":"ok"}
```

App beží v K8s! Port 30080 je NodePort definovaný v `values.yaml` → `service.nodePort`.

- [ ] **Krok 7: Vyskúšaj Helm upgrade**

```bash
helm upgrade devops-lab kubernetes/helm/devops-lab/ --set replicaCount=3
```

Sleduj rolling update:
```bash
kubectl get pods
# NAME                          READY   STATUS    RESTARTS
# devops-lab-xxx-yyy   1/1     Running   0
# devops-lab-aaa-bbb   1/1     Running   0
# devops-lab-ccc-ddd   1/1     Running   0   ← nový pod
```

**Čo je `helm upgrade`?** Zmení deployment bez downtime. K8s postupne reštartuje pody — vždy beží aspoň `replicaCount - 1` podov.

- [ ] **Krok 8: Pozri si helm históriu**

```bash
helm history devops-lab
# REVISION  STATUS     CHART               APP VERSION
# 1         superseded devops-lab-0.1.0    1.0.0
# 2         deployed   devops-lab-0.1.0    1.0.0
```

Každý `helm upgrade` = nová revision. Rollback je `helm rollback devops-lab 1`.

- [ ] **Krok 9: Commitni**

```bash
git add ansible/inventory/hosts.yml
git commit -m "feat: complete blok2 - ansible, github actions, k3s + helm"
git push
```

---

## Blok 2 — Záverečné overenie

- [ ] `curl http://<VM_IP>:8080/health` — app cez Docker priamo na VM
- [ ] `curl http://<VM_IP>:30080/health` — app cez K3s + Helm
- [ ] GitHub push do `main` (zmena v `app/`) → workflow prebehne automaticky
- [ ] `kubectl get pods` — 2+ running pody
- [ ] `helm list` — `devops-lab` release zobrazený

---

## Čo nasleduje — Blok 3

- Rozšírime Flask app o `/data` a `/messages` endpointy
- PostgreSQL — replication cluster, backups
- Apache Cassandra — distributed DB
- RabbitMQ — messaging

Pred Blokom 3: môžeš zmazať VM aby si šetril náklady:
```bash
# V Cloud Shelli
terraform destroy -target module.vm
```
