# MinIO Docker Stack

Self-hosted, S3-compatible object storage using [MinIO](https://min.io/), fully containerized with Docker Compose.

---

## What's Included

| Feature | Detail |
|---|---|
| MinIO Server | Latest stable image |
| Web Console | `http://SERVER_IP:9001` |
| S3 API | `http://SERVER_IP:9000` |
| Auto bucket creation | On first startup |
| Public download policy | Set automatically per bucket |
| Lifecycle rules | Auto-delete files after N days |
| Persistent storage | Docker named volume |

---

## Ports

| Port | Purpose |
|---|---|
| `9000` | S3 API Endpoint |
| `9001` | MinIO Web Console |

---

## Quick Start

### 1. Copy and configure environment file

```bash
cp .env.example .env
nano .env
```

Update at minimum:
- `MINIO_ROOT_USER` — change from default
- `MINIO_ROOT_PASSWORD` — change from default
- `MINIO_BUCKETS` — space-separated list of bucket names to create
- `MINIO_EXPIRE_DAYS` — how many days before files are auto-deleted

### 2. Start MinIO

```bash
docker compose up -d
```

This will:
1. Start the MinIO server
2. Wait for it to be healthy
3. Run the init container which:
   - Creates all buckets in `MINIO_BUCKETS`
   - Sets public download policy on each bucket
   - Adds a lifecycle expiration rule (auto-delete after `MINIO_EXPIRE_DAYS`)

### 3. Open the Web Console

```
http://localhost:9001
```

Login with the credentials from your `.env` file.

---

## Deploy on a New Server

```bash
# 1. Install Docker & Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Clone / copy this folder to the server
git clone <your-repo> minio-server
cd minio-server

# 3. Configure
cp .env.example .env
nano .env   # set strong credentials

# 4. Start
docker compose up -d
```

---

## Managing mc (MinIO Client)

You can run `mc` commands via the running init container or as a one-off:

```bash
# One-off mc command via Docker
docker run --rm -it \
  --network minio_minio_net \
  quay.io/minio/mc:latest \
  alias set myminio http://minio:9000 minioadmin minioadmin

# List buckets
docker run --rm -it \
  --network minio_minio_net \
  quay.io/minio/mc:latest \
  ls myminio
```

---

## Useful Commands

| Action | Command |
|---|---|
| Start | `docker compose up -d` |
| Stop | `docker compose down` |
| Restart | `docker compose restart minio` |
| View logs (live) | `docker compose logs -f minio` |
| View last 100 lines | `docker compose logs --tail=100 minio` |
| Open shell in mc | `docker run --rm -it --network minio_minio_net quay.io/minio/mc sh` |

---

## Accessing Files

Since buckets are set to **public download**, files are accessible without authentication:

```
http://SERVER_IP:9000/pctracking/image.png
```

Replace `SERVER_IP` with your server's IP address or domain name.

---

## Environment Variables Reference

| Variable | Default | Description |
|---|---|---|
| `MINIO_ROOT_USER` | `minioadmin` | Admin username |
| `MINIO_ROOT_PASSWORD` | `minioadmin` | Admin password |
| `MINIO_API_PORT` | `9000` | Host port for S3 API |
| `MINIO_CONSOLE_PORT` | `9001` | Host port for Web Console |
| `MINIO_BUCKETS` | `pctracking` | Space-separated bucket names |
| `MINIO_EXPIRE_DAYS` | `15` | Auto-delete files after N days |
| `MINIO_MAX_PRESIGNED_TTL` | `2592h` | Max presigned URL lifetime |

---

## Multiple Buckets

To create multiple buckets, space-separate them in `.env`:

```env
MINIO_BUCKETS=pctracking screenshots logs
```

All buckets will be created, made public, and have lifecycle rules applied automatically.

---

## Production Checklist

- [ ] Change `MINIO_ROOT_USER` from default
- [ ] Change `MINIO_ROOT_PASSWORD` from default (use a strong password)
- [ ] Use HTTPS (configure a reverse proxy like Nginx/Caddy)
- [ ] Configure firewall (only expose ports 9000/9001 as needed)
- [ ] Set up a domain name
- [ ] Monitor disk usage
- [ ] Test lifecycle rules
- [ ] Back up named volume: `docker run --rm -v minio_minio_data:/data -v $(pwd):/backup alpine tar czf /backup/minio-backup.tar.gz /data`

---

## Storage

Files are stored in a Docker named volume: `minio_minio_data`

To see where Docker stores it:

```bash
docker volume inspect minio_minio_data
```
