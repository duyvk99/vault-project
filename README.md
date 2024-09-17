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
## 1. Generate Self-signed TLS
- Generate CA in */tmp*

```bash
cfssl gencert -initca ./tls/ca-csr.json | cfssljson -bare /tmp/ca
```

- Create a self-signed certificate in */tmp*
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
  - Replace *vault.example.com* with real domain.
  - Replace $KUBE_NAMESPACE with real namespace 

- Put the self-signed certificate generated in the previous step to *./tls* folder in git repository.
```bash
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```

## 2. Vault Database
- Create a postgres database & a user.
```sql
CREATE DATABASE vault_server;
CREATE USER vault with ENCRYPTED PASSWORD '1gCXWBFBSA6qRUi';
ALTER DATABASE vault_server OWNER TO vault;
```
- Notes:
  -  Replace **vault** with vault postgres user name. 
  -  Replace **R4nd0mP4s$w0rD123** with vault postgres password .
  -  Replace **vault_server** with vault postgres database name.
</br>

- Create tables in a database and enable high availability.

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

- Grant Policies.
```sql
GRANT ALL PRIVILEGES ON DATABASE vault_server TO vault;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO  vault;
```

## 3. Install Vault Server
- Create vault server namespace.
```bash
kubectl create namespace $KUBE_NAMESPACE --context $KUBE_CONTEXT
```

- Create Kubernetes secret self-signed TLS.
```bash
kubectl -n $KUBE_NAMESPACE create secret tls tls-ca \
 --cert ./tls/ca.pem  \
 --key ./tls/ca-key.pem --context $KUBE_CONTEXT

kubectl -n $KUBE_NAMESPACE create secret tls tls-server \
  --cert ./tls/vault.pem \
  --key ./tls/vault-key.pem --context $KUBE_CONTEXT

```
- Create Vault Database Secrets.
```bash
kubectl create secret generic vault-db --from-file=config/config.hcl --namespace=$KUBE_NAMESPACE --context $KUBE_CONTEXT
```
- Notes:
  - Replace **VAULT_DB_USERNAME** with your database username in *config/config.hcl* file.
  - Replace **VAULT_DB_PASSWORD** with your database password in *config/config.hcl* file.
  - Replace **VAULT_DB_ENDPOINT** with your database endpoint in *config/config.hcl* file.
  
##### Create Vault Cluster
- Add helm repository.
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
```   
- Install/Upgrade Vault server.
```bash
helm upgrade --install vault hashicorp/vault --namespace $KUBE_NAMESPACE -f helm-values/values.yaml --kube-context $KUBE_CONTEXT
```
- Create ingress
```bash
kubectl apply -f helm-values/ingress.yaml --context $KUBE_CONTEXT
```

Notes:
- Remember to enable **--enable-ssl-passthrough** in the ingress-controller.

## 4. Unseal Vault
- Init Vault Server 
```bash
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator init 
```
- **Importants: Save the output of the init vault (show one time only)** 
- Unseal Vault Server
Using the **3/5** key in the vault init to unseal vault server
Remember to save the init output for unseal or generate the superadmin token with expired time
```bash
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 1>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 2>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator unseal <UNSEALED KEY 3>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 4>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 5>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-1 -- vault operator unseal <UNSEALED KEY 1>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 2>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 3>
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-2 -- vault operator unseal <UNSEALED KEY 1>
```

## 5. Auto Unseal with Vault Central
### 5.1. Generate Self-Signed TLS for Vault Central
- Generate CA in */tmp*

```bash
cfssl gencert -initca ./tls/ca-csr.json | cfssljson -bare /tmp/ca
```

- Create a self-signed certificate in */tmp*
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
  - Replace **vault-central.example.com** with the real domain.
- Put the self-signed certificate generated in the previous step to *./tls* folder in git repository.
```bash
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```

### 5.2. Vault Database
- Create a postgres database & a user.
```sql
CREATE DATABASE vault_central;
ALTER DATABASE vault_central OWNER TO vault;
```
- Notes:
  -  Replace **vault_central** with vault postgres database name.
</br>

- Create tables in a database.

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
```
- Grant Policies.
```sql
GRANT ALL PRIVILEGES ON DATABASE vault_server TO vault;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO  vault;
```

- Create Vault Central Standalone.
```bash
kubectl create namespace vault-central --context $KUBE_CONTEXT
helm upgrade --install vault-central hashicorp/vault --namespace vault-central -f helm-values/vault-central.yaml --kube-context $KUBE_CONTEXT
kubectl apply -f helm-values/vault-central-ingress.yaml --context $KUBE_CONTEXT

```
- Enable Secret Transit on Vault Central.
```bash
kubectl port-forward vault-central-0 -n vault-central --context $KUBE_CONTEXT 8200:8200

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
- Transit Auto-unseal token is renewed automatically by default
- Set **VAULT_TOKEN** environment variables of HA Vault cluster with previous step generate token (vault.yaml).
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
**[=> This is the use case for you!](terraform/README.md)**
## 7. Examples
**[=> This is the use case for you!](examples/README.md)**
## 8. Uninstall Vault
- Uninstall Helm Release & Addition Resouces from Kubernetes Cluster
```bash
helm uninstall vault --namespace $KUBE_NAMESPACE --kube-context $KUBE_CONTEXT
helm uninstall vault-central --namespace vault-central --kube-context $KUBE_CONTEXT
kubectl delete namespace project-demo --context $KUBE_CONTEXT
kubectl delete namespace $KUBE_NAMESPACE --context $KUBE_CONTEXT
kubectl delete namespace vault-central --context $KUBE_CONTEXT
helm repo remove hashicorp
```

- Drop Vault Database
```bash
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP DATABASE vault_server;'
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP DATABASE vault_central;'
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -U postgres -c 'DROP USER IF EXISTS vault;' 
```
