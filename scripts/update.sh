#!/usr/bin/env bash
set -euo pipefail

# cakeclaw 更新脚本
# 用法: sudo bash update.sh <新镜像tag>
# 例如: sudo bash update.sh ghcr.io/openclaw/openclaw:2026.7.2

NEW_TAG="${1:-}"
if [ -z "${NEW_TAG}" ]; then
  echo "用法: ./update.sh <新镜像tag>"
  echo "例如: ./update.sh ghcr.io/openclaw/openclaw:2026.7.2"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$PROJECT_DIR/.env" ] || { echo "缺少 .env 文件"; exit 1; }
set -a; source "$PROJECT_DIR/.env"; set +a

echo "更新到: ${NEW_TAG}"
echo "当前:   ${GATEWAY_IMAGE:-unknown}"

# 1. 备份
echo "[1/4] 备份当前状态..."
bash "$SCRIPT_DIR/backup.sh" 2>/dev/null || echo "  备份脚本不存在或失败，跳过"

# 2. 停旧容器
echo "[2/4] 停止旧容器..."
docker rm -f cakeclaw-gateway 2>/dev/null || true

# 3. 拉新镜像
echo "[3/4] 拉取新镜像..."
docker pull "${NEW_TAG}" || { echo "拉取失败"; exit 1; }

# 4. 更新 .env 的镜像变量
sed -i "s|^GATEWAY_IMAGE=.*|GATEWAY_IMAGE=${NEW_TAG}|" "$PROJECT_DIR/.env"

# 5. 重新部署
echo "[4/4] 启动新容器..."
cd "$PROJECT_DIR"
export GATEWAY_PORT="${GATEWAY_PORT:-18789}" GATEWAY_IMAGE="${NEW_TAG}"
export GATEWAY_MEM_LIMIT="${GATEWAY_MEM_LIMIT:-4g}" GATEWAY_CPU_LIMIT="${GATEWAY_CPU_LIMIT:-1}" GATEWAY_PID_LIMIT="${GATEWAY_PID_LIMIT:-1024}"
COMPOSE_FILE="/data/etc/openclaw/docker-compose.yml"
envsubst '$GATEWAY_PORT $GATEWAY_IMAGE $GATEWAY_MEM_LIMIT $GATEWAY_CPU_LIMIT $GATEWAY_PID_LIMIT' \
  < "$PROJECT_DIR/docker-compose.yml" > "${COMPOSE_FILE}"
if grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "${COMPOSE_FILE}"; then
  echo "[FAIL] docker-compose 生成失败：存在未替换的占位符" >&2
  exit 1
fi
chmod 600 "${COMPOSE_FILE}"
docker compose -f "${COMPOSE_FILE}" up -d

# 6. 验证：等健康检查 healthy（非仅 Up），覆盖 start_period 120s
for _ in $(seq 1 36); do
  sleep 5
  HS=$(docker inspect --format '{{.State.Health.Status}}' cakeclaw-gateway 2>/dev/null || echo "no-health")
  if [ "${HS}" = "healthy" ]; then
    echo "[OK] cakeclaw-gateway healthy"
    docker logs cakeclaw-gateway --tail 10 2>&1
    exit 0
  fi
  if [ "${HS}" = "unhealthy" ]; then
    echo "[FAIL] Gateway healthcheck 失败 (unhealthy)"
    docker logs cakeclaw-gateway --tail 30 2>&1
    exit 1
  fi
done
echo "[FAIL] Gateway 未在 180s 内变为 healthy"
docker logs cakeclaw-gateway --tail 30 2>&1
exit 1
