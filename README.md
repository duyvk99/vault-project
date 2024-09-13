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

# Setup - Vault Project
## 1. Generate TLS

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

## 5. Example
- **Notes: Export environments before doing examples!**
```bash
export VAULT_ADDR="https://vault.ist219.com"
export VAULT_TOKEN=""
export KUBE_CONTEXT=""
export KUBE_NAMESPACE=""
```
- Create sample secrets, policies & entities.
```bash
vault secrets enable -path=project-demo kv-v2
vault kv put -mount=project-demo project/demo/service-a-secret user=project password=demo
vault kv put -mount=project-demo project/demo/service-b-secret user=test password=Hello

vault policy write project/demo/service-a-secret examples/policies/service-a-policy.hcl
vault policy write project/demo/service-b-secret examples/policies/service-b-policy.hcl

entity_a_id=$(vault write -format=json identity/entity \
  name="project-demo-service-a" \
  policies="project/demo/service-a-secret" | jq -r '.data.id')
entity_b_id=$(vault write -format=json identity/entity \
  name="project-demo-service-b" \
  policies="project/demo/service-b-secret" | jq -r '.data.id')
```
##### 5.1 Vault Kubernetes Auth
- Create namespace for demo
```bash
kubectl --context $KUBE_CONTEXT create namespace project-demo
```
- Vault setup Kubernetes Auth
```bash
vault auth enable -path=kubernetes-demo kubernetes
vault write auth/kubernetes-demo/config \
kubernetes_host=""
kubernetes_accessor=$(vault auth list | grep "kubernetes-demo" | awk '{print $3}')

vault write identity/entity-alias \
  name="project-demo/service-a" \
  canonical_id=$entity_a_id \
  mount_accessor=$kubernetes_accessor
vault write identity/entity-alias \
  name="project-demo/service-b" \
  canonical_id=$entity_b_id \
  mount_accessor=$kubernetes_accessor

vault write auth/kubernetes-demo/role/project-demo-service-a \
  bound_service_account_names="service-a" \
  bound_service_account_namespaces="project-demo" \
  alias_name_source="serviceaccount_name" \
  ttl=24h
vault write auth/kubernetes-demo/role/project-demo-service-b \
  bound_service_account_names="service-b" \
  bound_service_account_namespaces="project-demo" \
  alias_name_source="serviceaccount_name" \
  ttl=24h
```
- Create Kubernetes service accounts & example pods.
```bash
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-a
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-b
kubectl --context $KUBE_CONTEXT apply -f examples/kubernetes-auth/service-a.yaml
kubectl --context $KUBE_CONTEXT apply -f examples/kubernetes-auth/service-b.yaml
```
- Demo gets secret from pod.
```bash
export VAULT_ADDR='https://vault.vault-server.svc.cluster.local:8200'
DEFAULT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
role=project-demo-service-a

- Login get token
token=$(curl -sSk "$VAULT_ADDR/v1/auth/kubernetes-demo/login" --data '
  {
    "jwt": "'$DEFAULT_TOKEN'",
    "role": "'$role'"
  }'| grep -oP '"client_token":\s*"\K[^"]+')

- Get Config
curl -sSk \
    --header "X-Vault-Token: $token" \
    $VAULT_ADDR/v1/project-demo/data/project/demo/service-a-secret
```
##### 5.2 Vault JWT/OIDC Auth
- Create namespace demo.
```bash
kubectl --context $KUBE_CONTEXT create namespace project-demo
```
- Vault setup Kubernetes JWT/OIDC Auth.
```bash
vault auth enable -path=jwt-demo jwt
ISSUER="$(kubectl get --raw /.well-known/openid-configuration --context kz-uat | jq -r '.issuer')"
vault write auth/jwt-demo/config oidc_discovery_url="${ISSUER}"

jwt_accessor=$(vault auth list | grep "jwt-demo" | awk '{print $3}')

vault write identity/entity-alias \
  name="system:serviceaccount:project-demo:service-a" \
  canonical_id=$entity_a_id \
  mount_accessor=$jwt_accessor
vault write identity/entity-alias \
  name="system:serviceaccount:project-demo:service-b" \
  canonical_id=$entity_b_id \
  mount_accessor=$jwt_accessor

cat <<EOF | vault write auth/jwt-demo/role/project-demo-service-a -
{
  "user_claim": "sub",
  "bound_audiences": "vault",
  "bound_subject": "system:serviceaccount:project-demo:service-a",
  "claim_mappings": {
    "/kubernetes.io/pod/name": "pod_name",
    "/kubernetes.io/serviceaccount/name": "service_account_name",
    "/kubernetes.io/serviceaccount/uid": "service_account_uid",
    "/kubernetes.io/namespace": "namespace",
    "iss": "cluster_url"
  },
  "role_type": "jwt",
  "ttl": "24h"
}
EOF

cat <<EOF | vault write auth/jwt-demo/role/project-demo-service-b -
{
  "user_claim": "sub",
  "bound_audiences": "vault",
  "bound_subject": "system:serviceaccount:project-demo:service-b",
  "claim_mappings": {
    "/kubernetes.io/pod/name": "pod_name",
    "/kubernetes.io/serviceaccount/name": "service_account_name",
    "/kubernetes.io/serviceaccount/uid": "service_account_uid",
    "/kubernetes.io/namespace": "namespace",
    "iss": "cluster_url"
  },
  "role_type": "jwt",
  "ttl": "24h"
}
EOF
```
- Create Kubernetes service accounts & example pods.
```bash
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-a
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-b
kubectl --context $KUBE_CONTEXT apply -f examples/jwt-auth/service-a.yaml
kubectl --context $KUBE_CONTEXT apply -f examples/jwt-auth/service-b.yaml
```
- Demo gets secret from pod.
```bash
export VAULT_ADDR='https://vault.dtsdemo.com'
DEFAULT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CUSTOMIZED_TOKEN=$(cat /var/run/secrets/tokens/vault)
role=project-demo-service-a

- Login get token
token=$(curl -sSk "$VAULT_ADDR/v1/auth/jwt-demo/login" --data '
  {
    "jwt": "'$DEFAULT_TOKEN'",
    "role": "'$role'"
  }'| grep -oP '"client_token":\s*"\K[^"]+')

- Get Config
curl -sSk \
    --header "X-Vault-Token: $token" \
    $VAULT_ADDR/v1/project-demo/data/project/demo/service-a-secret
```
Get token info
```bash
vault token lookup --format=json $token
```
## 6. Auto Unseal with Vault Central
### 6.1. Generate TLS Vault Central
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
  - Replace *vault-central.example.com* with real domain.
- Put the self-signed certificate generated in the previous step to *./tls* folder in git repository.
```bash
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```

### 6.2. Vault Database
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

- Create Vault Central Server
```bash
kubectl create namespace vault-central --context $KUBE_CONTEXT
helm upgrade --install vault-central hashicorp/vault --namespace vault-central -f helm-values/vault-central.yaml --kube-context $KUBE_CONTEXT
kubectl apply -f helm-values/vault-central-ingress.yaml --context $KUBE_CONTEXT

```
- Enable Transit on Vault Central
```bash
# separate window
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
- Set VAULT_TOKEN environment variables of HA Vault cluster with previous step generate token (vault.yaml).
```hcl
      seal "transit" {
        address = "https://vault-central.vault-central.svc:8200"
        disable_renewal = "false"
        key_name = "autounseal"
        mount_path = "transit/"
        tls_skip_verify = "true"
      }
```

<!-- ## 7. Auto-Auth
## 8. Database Credential Rotation -->
## 7. Uninstall Vault
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
