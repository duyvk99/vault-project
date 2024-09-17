- [Setup - Vault Project](#setup---vault-project)
  - [1. Generate TLS](#1-generate-tls)
  - [2. Vault Database](#2-vault-database)
  - [3. Install Vault Server](#3-install-vault-server)
        - [Create Vault Cluster](#create-vault-cluster)
  - [4. Unseal Vault](#4-unseal-vault)
  - [5. Example](#5-example)
        - [5.1 Vault Kubernetes Auth](#51-vault-kubernetes-auth)
        - [5.2 Vault JWT/OIDC Auth](#52-vault-jwtoidc-auth)
  - [6. Auto Unseal with Vault Central](#6-auto-unseal-with-vault-central)
    - [6.1. Generate TLS Vault Central](#61-generate-tls-vault-central)
    - [6.2. Vault Database](#62-vault-database)
  - [7. Uninstall Vault](#7-uninstall-vault)

# Setup - Vault Cluster
## 1. Generate Self-signed TLS Certificate
-  There are many ways to initialize self-signed SSL certificate;in this article, we will use CloudflareSSL.
- The following command creates “ca.pem” and “ca-key.pem”
```bash
cfssl gencert -initca ./tls/ca-csr.json | cfssljson -bare /tmp/ca
```
- The following command create self-signed certificate:

```bash
cfssl gencert \
  -ca=/tmp/ca.pem \
  -ca-key=/tmp/ca-key.pem \
  -config=./tls/ca-config.json \
  -hostname="vault.example.com,vault,vault.$KUBE_NAMESPACE.svc.cluster.local,vault.$KUBE_NAMESPACE.svc,localhost,127.0.0.1" \
  -profile=default \
  ./tls/ca-csr.json | cfssljson -bare /tmp/vault
```
- Notes:
  - Replace `vault.example.com` to the domain you are using.
  - Replace `$KUBE_NAMESPACE` to the namespace you are using to install Vault. 
- Move the self-signed certificate that was created in the previous step to the `./tls` folder.
```bash
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```
## 2. Vault Storage
- There are many types of storage backends that can be used; in this article, we will use a PostgreSQL database as the storage backend for the Vault cluster.
- Create a PostgreSQL database and user.
```sql
CREATE DATABASE vault_server;
CREATE USER vault with ENCRYPTED PASSWORD 'R4nd0mP4s$w0rD123';
ALTER DATABASE vault_server OWNER TO vault;
```
- Notes:
  - Replace `vault` with the PostgreSQL username for Vault.
  - Replace `R4nd0mP4s$w0rD123` with the PostgreSQL password for Vault.
  - Replace `vault_server` with the PostgreSQL database name for Vault.
</br>
- Setup Vault database table and enable high avaiability.
```sql
\c vault_server;

CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);

CREATE TABLE vault_ha_locks (
  ha_key                                      TEXT COLLATE "C" NOT NULL,
  ha_identity                                 TEXT COLLATE "C" NOT NULL,
  ha_value                                    TEXT COLLATE "C",
  valid_until                                 TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT ha_key PRIMARY KEY (ha_key)
);
```
- Grant permissions to the user created above.
```sql
GRANT ALL PRIVILEGES ON DATABASE vault_server TO vault;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO  vault;
```
## 3. Install Vault Cluster
- Create Vault kubernetes namespace.
```bash
kubectl create namespace $KUBE_NAMESPACE
```
- Create Kubernetes secret for self-signed TLS certificate.
```bash
kubectl -n $KUBE_NAMESPACE create secret tls tls-ca \
 --cert ./tls/ca.pem  \
 --key ./tls/ca-key.pem

kubectl -n $KUBE_NAMESPACE create secret tls tls-server \
  --cert ./tls/vault.pem \
  --key ./tls/vault-key.pem
```
- Create Kubernetes secret for Vault database.
```bash
kubectl create secret generic vault-db --from-file=config/config.hcl --namespace=$KUBE_NAMESPACE
```
- Add helm repository.
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
```   
- Install/Upgrade Vault cluster.
```bash
helm upgrade --install vault hashicorp/vault --namespace $KUBE_NAMESPACE -f helm-values/values.yaml
```
- Create ingress
```bash
kubectl apply -f helm-values/ingress.yaml
```
- Notes:
  - Replace `$KUBE_NAMESPACE` with your Vault kubernetes namespace.
  - Ensure that `--enable-ssl-passthrough` is enabled in the ingress controller.
## 4. Unseal Vault
-  Initializes a Vault server.
```bash
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator init 
```
- Notes:
  - **Important: Save the output from the Vault initialization (it is shown only once).**
  - Unseal the Vault Server: Use **3 out of 5** keys from the Vault initialization to unseal the server.
  Remember to save the initialization output for unsealing or generate a superadmin token with an expiration time.
```bash
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 1>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 2>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 3>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 4>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 5>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 1>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 2>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 3>
kubectl exec --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 1>
```
## 5. Auto Unseal with Vault Central
### 5.1. Generate Self-signed TLS Certificate for Vault Central
- Create “ca.pem” and “ca-key.pem”

```bash
cfssl gencert -initca ./tls/ca-csr.json | cfssljson -bare /tmp/ca
```

- Create self-signed certificate
```bash
cfssl gencert \
  -ca=/tmp/ca.pem \
  -ca-key=/tmp/ca-key.pem \
  -config=./tls/ca-config.json \
  -hostname="vault-central.example.com,vault-central,vault-central.vault-central.svc.cluster.local,vault-central.vault-central.svc,localhost,127.0.0.1" \
  -profile=default \
  ./tls/ca-csr.json | cfssljson -bare /tmp/vault
```
- Notes:
  - Replace `vault-central.example.com` to the domain you are using.
- Move the self-signed certificate that was created in the previous step to the `./tls` folder.
```bash
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```
### 5.2. Vault Database
- Create PostgreSQL database for Vault central.
```sql
CREATE DATABASE vault_central;
ALTER DATABASE vault_central OWNER TO vault;
```
- Notes:
    - Replace `vault_central` with the name of your PostgreSQL database for Vault.
</br>
- Setup Vault database table.
```sql
\c vault_central;

CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);
```
- Grant permissions to vault user.
```sql
GRANT ALL PRIVILEGES ON DATABASE vault_central TO vault;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO  vault;
```
- Create Vault Standalone (Vault Central).
```bash
kubectl create namespace vault-central
helm upgrade --install vault-central hashicorp/vault --namespace vault-central -f helm-values/vault-central.yaml
kubectl apply -f helm-values/vault-central-ingress.yaml
```
- Enable Secret Transit on Vault Central.
```bash
kubectl port-forward vault-central-0 -n vault-central 8200:8200

export VAULT_ADDR="https://127.0.0.1:8200"

# use 'root_token' generated during Vault initialization
vault login

# create transit secret 
vault secrets enable transit
vault write -f transit/keys/autounseal
vault policy write autounseal config/autounseal-policy.hcl
vault token create -orphan -policy=autounseal -period=24h

Key                  Value
---                  -----
token                <secret-token>
token_accessor       wkTM4nsF0ehkRvIuBD9cedHC
token_duration       24h
token_renewable      true
token_policies       ["autounseal" "default"]
identity_policies    []
policies             ["autounseal" "default"]
```
- Notes:
  - The Transit Auto-unseal token is renewed automatically by default.
  - Set the `VAULT_TOKEN` environment in the Vault cluster with the token generated in the previous step (`./helm-values/vault-cluster/vault.yaml`).
```hcl
      seal "transit" {
        address = "https://vault-central.vault-central.svc:8200"
        disable_renewal = "false"
        key_name = "autounseal"
        mount_path = "transit/"
        tls_skip_verify = "true"
      }
```
## 6. Setup Resources
**[=> Using terraform setup resource.](terraform/README.md)**
## 7. Examples
**[=> Vault Example](examples/README.md)**
## 8. Uninstall Vault 
- Uninstall Helm release and addition resouces from Kubernetes.
```bash
helm uninstall vault --namespace $KUBE_NAMESPACE --kube-context $KUBE_CONTEXT
helm uninstall vault-central --namespace vault-central --kube-context $KUBE_CONTEXT
kubectl delete namespace project-demo
kubectl delete namespace $KUBE_NAMESPACE
kubectl delete namespace vault-central
helm repo remove hashicorp
```
- Drop Vault Database
```bash
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP DATABASE vault_server;'
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP DATABASE vault_central;'
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP USER IF EXISTS vault;' 
```
