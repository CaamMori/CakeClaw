# cakeclaw

Self-hosted AI DevOps Agent — baked with OpenClaw.

> **当前为个人/小规模部署。生产环境请自行加固认证、日志轮转和访问控制。**

## 一句话

基于 OpenClaw 构建的自托管 AI 运维工程师系统。一个脚本部署，无域名也能跑。

## 快速开始

```bash
git clone https://github.com/CaamMori/CakeClaw.git cakeclaw
cd cakeclaw
sudo ./scripts/install.sh   # 12 步全自动部署
```

### 可选：Codex Responses 修复

如果你的模型 provider 指向 ChatGPT Subscription / Codex（type=57）后端（只支持 `/v1/responses`），
OpenClaw 会把 system prompt 当成 `input[].role="system"` 发送而被后端拒绝：

```
400 System messages are not allowed
```

cakeclaw 提供一键开关修好它（bind mount 一个改好的 dist 文件 + 环境变量白名单，不重新 build 镜像）。
根据你的模型 `api` 取值，选一个开关：

#### 方案 B（推荐，覆盖 `api: "openai-responses"`）

绝大多数自定义 Codex 中转的把 provider `api` 写成 `openai-responses`。这种情况用：

```bash
sudo ./scripts/install.sh --with-codex-fix-b
```

#### Option C（仅 `api` 已是 Codex 专属值）

若模型 `api` 已经是 `openai-chatgpt-responses` 或 `openclaw-openai-responses-transport`，用：

```bash
sudo ./scripts/install.sh --with-codex-fix
```

启用后，指定 provider 白名单（两方案都要）：

```bash
# .env 里（或安装后手动改 /data/etc/openclaw/runtime.env）
CODEX_RESPONSES_PROVIDERS=caner
```

> 也可不走命令行参数，而在 `.env` 里设 `CODEX_FIX=1` 或 `CODEX_FIX_B=1`。
> 两开关互斥，不能同时开启。实现细节见 `patches/` 与 `docs/`。

部署完成后：

`install.sh` 末尾会交互式引导你配置模型 provider（可直接回车跳过）：
1. 选**哪家 API**（OpenAI / Claude / Azure / OpenAI 兼容）
2. 填 API Key（Azure/兼容格式还需 Base URL）
3. 脚本自动拉取该家的模型列表，勾选你要的模型
4. 自动写入 `gateway.json` 并重启 Gateway 生效

若跳过了，也可稍后手动配：
1. 打开 Gateway 控制台（`http://<IP>:8080` 或无域名 `8080`）
2. 在 `gateway.json` 里配 `models.providers` 的 API Key + Base URL + Model
3. 重启 Gateway 即生效

- 有域名 → `sudo ./scripts/install.sh` 引导 HTTPS + Certbot
- 没域名 → HTTP + 8080

```bash
sudo ./scripts/install.sh --help    # 可选: --no-phase2 --no-phase3 跳过监控/审计
```

## 脚本

| 脚本 | 用途 | 安装方式 |
|------|------|----------|
| `install.sh` | 一键部署 | 手动执行 |
| `uninstall.sh` | 完整卸载 | 手动执行 |
| `update.sh` | 版本更新 | 手动执行 |
| `backup.sh` | 状态备份 | cron 自动 |
| `watchdog.sh` | 健康评分 + 自动重启 | cron 自动 |
| `alert.sh` | 告警通知 | watchdog 内调用 |
| `trends.sh` | 周报聚合 | cron 自动 |
| `cert-check.sh` | 证书到期提醒 | cron 自动 |
| `audit.sh` | 审计日志 | cron 自动 |
| `changelog.sh` | 变更记录 | 手动/Agent 调用 |
| `kbase.sh` | 知识库维护 | 手动执行 |
| `failover.sh` | 主备切换 | 手动/定时执行 |
| `sync.sh` | 跨节点备份 | 手动配置 cron |
| `worker-register.sh` | Worker 注册到 Master | 手动（Phase 4） |
| `master-discover.sh` | Master 心跳发现 Worker | cron（Phase 4） |

> 自动任务（backup/watchdog/trends/cert-check/audit/health-check）由 install.sh 写入
> `/etc/cron.d/cakeclaw-*` 独立文件管理（不污染 root crontab，可精确卸载）。
> 日志轮转由 `/etc/logrotate.d/cakeclaw` 控制，防止 `/data/logs/*.log` 无限增长。

## 模板

- `templates/SOUL.md` — Agent 行为契约
- `templates/AGENTS.md` — 安全策略模板
- `templates/gateway.json` — Gateway 配置骨架

## 文档

- [安全模型](docs/security.md)
- [部署与排错](docs/deploy-troubleshoot.md)
- [Phase 4 多节点设计](docs/phase4-plan.md)

## License

MIT
