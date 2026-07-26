#!/bin/sh
# =============================================================================
# MinIO Initialization Script
# Runs inside the minio-init container on first startup.
#
# What it does:
#   1. Waits for MinIO server to be ready
#   2. Creates all buckets defined in MINIO_BUCKETS
#   3. Sets public download policy on each bucket
#   4. Adds lifecycle expiration rule to each bucket
# =============================================================================

set -e

echo "==> Waiting for MinIO to be ready..."
until mc alias set myminio "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --insecure; do
  echo "  MinIO not ready yet — retrying in 3s..."
  sleep 3
done
echo "  Connected to MinIO successfully."

echo ""
echo "==> Creating buckets..."
for bucket in $MINIO_BUCKETS; do
  if mc ls "myminio/$bucket" > /dev/null 2>&1; then
    echo "  Bucket '$bucket' already exists — skipping."
  else
    mc mb "myminio/$bucket"
    echo "  Created bucket: $bucket"
  fi
done

echo ""
echo "==> Setting public download policy on buckets..."
for bucket in $MINIO_BUCKETS; do
  mc anonymous set download "myminio/$bucket"
  echo "  Public policy set on: $bucket"
done

echo ""
echo "==> Setting lifecycle rules (expire after ${MINIO_EXPIRE_DAYS} days)..."
for bucket in $MINIO_BUCKETS; do
  mc ilm rule add "myminio/$bucket" --expire-days "$MINIO_EXPIRE_DAYS"
  echo "  Lifecycle rule added to: $bucket (expire after ${MINIO_EXPIRE_DAYS} days)"
done

echo ""
echo "============================================"
echo "  MinIO initialization complete!"
echo "  Buckets  : $MINIO_BUCKETS"
echo "  Expire   : ${MINIO_EXPIRE_DAYS} days"
echo "  API      : http://minio:9000"
echo "  Console  : http://minio:9001"
echo "============================================"
