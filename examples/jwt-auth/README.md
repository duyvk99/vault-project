# Example Vault JWT/OIDC Auth
## 1. Config Auth Method & Secrets
### 1.1. Option 1: Manual Setup
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
- Setup JWT auth resources.
```bash
vault auth enable -path=jwt-demo jwt
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer')"
vault write auth/jwt-demo/config oidc_discovery_url="${ISSUER}"

jwt_accessor=$(vault auth list | grep "jwt-demo" | awk '{print $3}')

vault write identity/entity-alias \
  name="system:serviceaccount:project-demo:service-a" \
  canonical_id=$service_a_entity_id \
  mount_accessor=$jwt_accessor
vault write identity/entity-alias \
  name="system:serviceaccount:project-demo:service-b" \
  canonical_id=$service_b_entity_id \
  mount_accessor=$jwt_accessor

cat <<EOF | vault write auth/jwt-demo/role/demo-dev-service-a -
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

cat <<EOF | vault write auth/jwt-demo/role/demo-dev-service-b -
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
### 1.2. Option 2: Terraform Setup
- Fill in all the empty variables in `examples/jwt-auth/jwt-terraform-example/terraform.tfvars.example`, then apply the Terraform configuration to create the resources.
```
cd examples/jwt-auth/jwt-terraform-example
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply --auto-approve
```
## 2. Demo
- Create example pods.
```bash
kubectl create namespace project-demo
kubectl apply -f examples/jwt-auth/service-a.yaml
kubectl apply -f examples/jwt-auth/service-b.yaml
```
- Demo gets secret from pod.
```bash
export VAULT_ADDR='https://vault.dtsdemo.com'
CUSTOMIZED_TOKEN=$(cat /var/run/secrets/tokens/vault)
ROLE=demo-dev-service-a

# - Login get token
TOKEN=$(curl -sSk "$VAULT_ADDR/v1/auth/jwt-demo/login" --data '
  {
    "jwt": "'$CUSTOMIZED_TOKEN'",
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

Get token info
- The token will have an expiration time of 1 day, but in the pod, when a new pod is created, the service account token will expire in 10 minutes based on the pod's configuration, preventing the creation of a new token.
```bash
vault token lookup --format=json $token
```
## 3. Auto Auth Vault
- Init Resources auto authenticates.
```
kubectl -n project-demo delete pod service-a
kubectl apply -f examples/jwt-auth/auto-authen.yaml
```
- Get Secret
```
kubectl exec -it -n project-demo service-a sh
cat /secret/secret.json
```
## 4. Cleanup
- Delete Vault Resources.
```
vault auth disable jwt-demo
vault policy delete demo/dev/service-a-secret
vault policy delete demo/dev/service-b-secret
vault delete identity/entity/name/demo-dev-service-a
vault delete identity/entity/name/demo-dev-service-b
```
- Delete Kubernetes Resources.
```
kubectl delete -f examples/jwt-auth/service-a.yaml
kubectl delete -f examples/jwt-auth/service-b.yaml
kubectl delete namespace project-demo
```