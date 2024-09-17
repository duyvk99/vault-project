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
