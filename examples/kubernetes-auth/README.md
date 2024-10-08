# Example - Vault Kubernetes Auth
## 1. Config Auth Method & Secrets
### 1.1. Manual Setup
- **Notes: Export environments before doing examples!**
```bash
export VAULT_ADDR="https://vault.dtsdemo.com"
export VAULT_TOKEN=""
export KUBE_NAMESPACE=""
```
- Create sample secrets.
```bash
vault secrets enable -path=secret-demo kv-v2
vault kv put -mount=secret-demo demo/dev/secret_service_a user=danny-example01 password=Danny#123
vault kv put -mount=secret-demo demo/dev/secret_service_b config=example-secret user=username1 password=Hello
```
- Create policies & entities.
```
vault policy write demo/dev/service-a-secret examples/policies/service-a-policy.hcl
vault policy write demo/dev/service-b-secret examples/policies/service-b-policy.hcl

service_a_entity_id=$(vault write -format=json identity/entity \
  name="demo-dev-service-a" \
  policies="demo/dev/service-a-secret" | jq -r '.data.id')
service_b_entity_id=$(vault write -format=json identity/entity \
  name="demo-dev-service-b" \
  policies="demo/dev/service-b-secret" | jq -r '.data.id')
```
- Vault setup Kubernetes Auth
```bash
kubectl cluster-info | head -n 1 | grep -oP 'https?://[^\s]+'
vault auth enable -path=kubernetes-demo kubernetes
vault write auth/kubernetes-demo/config \
kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
kubernetes_accessor=$(vault auth list | grep "kubernetes-demo" | awk '{print $3}')

# Format name: nanemspace/service-account or service account UID
vault write identity/entity-alias \
  name="project-demo/service-a" \
  canonical_id=$service_a_entity_id \
  mount_accessor=$kubernetes_accessor
vault write identity/entity-alias \
  name="project-demo/service-b" \
  canonical_id=$service_b_entity_id \
  mount_accessor=$kubernetes_accessor

vault write auth/kubernetes-demo/role/demo-dev-service-a \
  bound_service_account_names="service-a" \
  bound_service_account_namespaces="project-demo" \
  alias_name_source="serviceaccount_name" \
  ttl=24h
vault write auth/kubernetes-demo/role/demo-dev-service-b \
  bound_service_account_names="service-b" \
  bound_service_account_namespaces="project-demo" \
  alias_name_source="serviceaccount_name" \
  ttl=24h
```
### 1.2. Option 2: Terraform Setup
- Fill in all the empty variables in `examples/kubernetes-auth/kubernetes-terraform-example/terraform.tfvars.example`, then apply the Terraform configuration to create the resources.
```
cd examples/kubernetes-auth/kubernetes-terraform-example
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply --auto-approve
```
## 2. Demo
- Create example pods.

```bash
kubectl create namespace project-demo
kubectl apply -f examples/kubernetes-auth/service-a.yaml
kubectl apply -f examples/kubernetes-auth/service-b.yaml
```
- Demo gets secret from pod.
```bash
export VAULT_ADDR='https://vault.dtsdemo.com'
DEFAULT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
ROLE=demo-dev-service-a

- Login get token
TOKEN=$(curl -sSk "$VAULT_ADDR/v1/auth/kubernetes-demo/login" --data '
  {
    "jwt": "'$DEFAULT_TOKEN'",
    "role": "'$ROLE'"
  }'| grep -oP '"client_token":\s*"\K[^"]+')

# - Get Config
curl -sSk \
    --header "X-Vault-Token: $TOKEN" \
    $VAULT_ADDR/v1/secret-demo/data/demo/dev/secret_service_a
# - Get config dont have permission
curl -sSk \
    --header "X-Vault-Token: $TOKEN" \
    $VAULT_ADDR/v1/secret-demo/data/demo/dev/secret_service_b
```

- Get token info
```bash
vault token lookup --format=json $token
```
## 3. Auto Auth Vault
- Init Resources auto authenticates.
```
kubectl -n project-demo delete pod service-a
kubectl apply -f examples/kubernetes-auth/auto-authen.yaml
```
- Get Secret
```
kubectl exec -it -n project-demo service-a sh
cat /secret/secret.json
```
## 4. Cleanup
- Delete Vault Resources.
```
vault auth disable kubernetes-demo
vault policy delete demo/dev/service-a-secret
vault policy delete demo/dev/service-b-secret
vault delete identity/entity/name/demo-dev-service-a
vault delete identity/entity/name/demo-dev-service-b
```
- Delete Kubernetes Resources.
```
kubectl delete -f examples/kubernetes-auth/service-a.yaml
kubectl delete -f examples/kubernetes-auth/service-b.yaml
kubectl delete namespace project-demo
```