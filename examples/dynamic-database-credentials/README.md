# Example - Users Management
- Enable and config Postgres secret engine.
```bash
vault secrets enable database
vault write database/config/postgresql \
     plugin_name=postgresql-database-plugin \
     connection_url="postgresql://{{username}}:{{password}}@$POSTGRES_URL/postgres?sslmode=disable" \
     allowed_roles=readonly \
     username="root" \
     password="rootpassword"
```
- Policies
```bash
vault write database/roles/readonly \
      db_name=postgresql \
      creation_statements=@readonly.sql \
      default_ttl=1h \
      max_ttl=24h
```
- Read new credentials from the readonly database role.
```bash
vault read database/creds/readonly
Key                Value
---                -----
lease_id           database/creds/readonly/P6tTTiWsR1fVCp0btLktU0Dm
lease_duration     1m
lease_renewable    true
password           A1a-pfgGk7Ptb0TxGBJI
username           v-token-readonly-9blxDY3dIKXsFMkv8kvH-1600278284
```
- Using Credentials have TTL access database.
```bash
psql -h $POSTGRES_URL -U v-token-readonly-9blxDY3dIKXsFMkv8kvH-1600278284 -d $POSTGRES_DATABASE
```