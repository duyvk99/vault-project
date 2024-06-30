# Setup - Vault Project

1. [Generate TLS](#1-generate-tls)
2. [Vault Database](#2-vault-database)
3. [Vault Cluster](#3-install-vault-server)
4. [Unseal Vault](#4-unseal-vault)
5. [Example](#5-example)
    1. [Vault Kubernetes Auth](#51-vault-kubernetes-auth)
    2. [Vault Kubernetes JWT/OIDC](#52-vault-jwtoidc-auth)


## 1. Generate TLS

- Generate CA in */tmp*

```
cfssl gencert -initca ./tls/ca-csr.json | cfssljson -bare /tmp/ca
```

- Create a self-signed certificate in */tmp*
```
cfssl gencert \
  -ca=/tmp/ca.pem \
  -ca-key=/tmp/ca-key.pem \
  -config=./tls/ca-config.json \
  -hostname="vault.example.com,vault,vault.$KUBE_NAMESPACE.svc.cluster.local,vault.$KUBE_NAMESPACE.svc,localhost,127.0.0.1" \
  -profile=default \
  ./tls/ca-csr.json | cfssljson -bare /tmp/vault
```
- Notes:
  - Replace *vault.example.com* with the real domain.

- Put the self-signed certificate generated in the previous step to *./tls* folder in git repository.
```
mv /tmp/ca* ./tls
mv /tmp/vault* ./tls
```

## 2. Vault Database
- Create a postgres database & a user.
```
CREATE DATABASE vault_server;
CREATE USER vault with ENCRYPTED PASSWORD 'R4nd0mP4s$w0rD123';
ALTER DATABASE vault_server OWNER TO vault;
```
- Notes:
  -  Replace *vault* with vault postgres user name. 
  -  Replace *R4nd0mP4s$w0rD123* with vault postgres password .
  -  Replace *vault_server* with vault postgres database name.
</br>

- Create tables in a database and enable high availability.

```
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
```
GRANT ALL PRIVILEGES ON DATABASE vault_server TO vault;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO  vault;
```

## 3. Install Vault Server
- Create vault server namespace.
```
kubectl create namespace $KUBE_NAMESPACE --context $KUBE_CONTEXT
```

- Create Kubernetes secret self-signed TLS.
```
kubectl -n $KUBE_NAMESPACE create secret tls tls-ca \
 --cert ./tls/ca.pem  \
 --key ./tls/ca-key.pem --context $KUBE_CONTEXT

kubectl -n $KUBE_NAMESPACE create secret tls tls-server \
  --cert ./tls/vault.pem \
  --key ./tls/vault-key.pem --context $KUBE_CONTEXT

```

##### Create Vault Cluster
- Add helm repository.
```
helm repo add hashicorp https://helm.releases.hashicorp.com
```   
- Install/Upgrade Vault server.
```
helm upgrade --install vault hashicorp/vault --namespace $KUBE_NAMESPACE -f helm-values/values.yaml --kube-context $KUBE_CONTEXT
```
- Create ingress
```
kubectl apply -f helm-values/ingress.yaml --context $KUBE_CONTEXT
```

Notes:
- Remember to enable **--enable-ssl-passthrough** in the ingress-controller.


## 4. Unseal Vault
- Init Vault Server 
```
kubectl exec --context $KUBE_CONTEXT --namespace $KUBE_NAMESPACE --stdin=true --tty=true vault-0 -- vault operator init 
```
- **Importants: Save the output of the init vault (show one time only)** 
- Unseal Vault Server
Using the **3/5** key in the vault init to unseal vault server
Remember to save the init output for unseal or generate the superadmin token with expired time
```
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
```
export VAULT_ADDR="https://vault.ist219.com"
export VAULT_TOKEN=""
export KUBE_CONTEXT=""
export KUBE_NAMESPACE=""
```
- Create sample secrets, policies & entities.
```
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
```
kubectl --context $KUBE_CONTEXT create namespace project-demo
```
- Vault setup Kubernetes Auth
```
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
```
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-a
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-b
kubectl --context $KUBE_CONTEXT apply -f examples/kubernetes-auth/service-a.yaml
kubectl --context $KUBE_CONTEXT apply -f examples/kubernetes-auth/service-b.yaml
```
- Demo gets secret from pod.
```
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
```
kubectl --context $KUBE_CONTEXT create namespace project-demo
```
- Vault setup Kubernetes JWT/OIDC Auth.
```
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
```
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-a
kubectl --context $KUBE_CONTEXT -n project-demo create sa service-b
kubectl --context $KUBE_CONTEXT apply -f examples/jwt-auth/service-a.yaml
kubectl --context $KUBE_CONTEXT apply -f examples/jwt-auth/service-b.yaml
```
- Demo gets secret from pod.
```
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
```
vault token lookup --format=json $token
```
