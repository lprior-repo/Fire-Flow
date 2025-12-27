# Hatchet Bare Metal Installation (Zero Docker)

## Prerequisites

```bash
# Ubuntu/Debian
sudo apt install -y postgresql-15 golang-go nodejs npm git
npm install -g pnpm
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

## 1. PostgreSQL

```bash
sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE USER hatchet WITH PASSWORD 'hatchet';"
sudo -u postgres psql -c "CREATE DATABASE hatchet OWNER hatchet;"
```

## 2. Clone and Build

```bash
git clone https://github.com/hatchet-dev/hatchet.git
cd hatchet

go build -o bin/hatchet-engine ./cmd/hatchet-engine
go build -o bin/hatchet-api ./cmd/hatchet-api
go build -o bin/hatchet-admin ./cmd/hatchet-admin
go build -o bin/hatchet-migrate ./cmd/hatchet-migrate
```

## 3. Setup (uses their Taskfile)

```bash
# Start only Postgres (skip their docker compose)
task setup  # runs migrations, generates keys, seeds DB
```

Or manually:

```bash
export DATABASE_URL="postgresql://hatchet:hatchet@localhost:5432/hatchet"
./bin/hatchet-migrate up
cp -r ./hack/dev/encryption-keys ./keys
./bin/hatchet-admin seed --admin-email admin@localhost --admin-password changeme
```

## 4. Environment

```bash
cat > .env <<'EOF'
DATABASE_URL=postgresql://hatchet:hatchet@localhost:5432/hatchet
SERVER_ENCRYPTION_MASTER_KEYSET_FILE=./keys/master.key
SERVER_ENCRYPTION_JWT_PRIVATE_KEYSET_FILE=./keys/private_ec256.key
SERVER_ENCRYPTION_JWT_PUBLIC_KEYSET_FILE=./keys/public_ec256.key
SERVER_PORT=8080
SERVER_URL=http://localhost:8080
SERVER_AUTH_COOKIE_SECRETS=random-secret-here
SERVER_AUTH_COOKIE_INSECURE=true
SERVER_AUTH_SET_EMAIL_VERIFIED=true
SERVER_GRPC_PORT=7077
SERVER_GRPC_BIND_ADDRESS=0.0.0.0
SERVER_GRPC_BROADCAST_ADDRESS=localhost:7077
SERVER_GRPC_INSECURE=true
SERVER_MSGQUEUE_KIND=postgres
SERVER_LOGGER_LEVEL=info
EOF
```

## 5. Run

```bash
set -a; source .env; set +a

# Terminal 1: Engine
./bin/hatchet-engine

# Terminal 2: API + Dashboard
./bin/hatchet-api
```

## 6. Access

- Dashboard: http://localhost:8080
- Login: admin@localhost / changeme

## 7. Create Worker Token

```bash
./bin/hatchet-admin token create --name worker --tenant-id <TENANT_ID_FROM_SEED>
```

## Summary

| Component      | What                  |
|----------------|-----------------------|
| PostgreSQL     | Native install        |
| hatchet-engine | Go binary you built   |
| hatchet-api    | Go binary you built   |
| Workers        | Your Go binaries      |

Zero Docker. All native binaries.
