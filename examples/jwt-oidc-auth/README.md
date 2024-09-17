## 5. Example Vault JWT/OIDC Auth
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
