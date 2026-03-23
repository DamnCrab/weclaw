# WeClaw

[English](README.md)

微信 AI Agent 桥接器 — 通过 [iLink](https://www.ilink.wiki) API 将微信消息接入 AI 编程助手（Claude、Codex、Gemini、Kimi 等）。

| | | |
|:---:|:---:|:---:|
| <img src="previews/preview1.png" width="280" /> | <img src="previews/preview2.png" width="280" /> | <img src="previews/preview3.png" width="280" /> |

## 快速开始

```bash
# 一键安装
curl -sSL https://raw.githubusercontent.com/fastclaw-ai/weclaw/main/install.sh | sh

# 启动（首次运行会弹出微信扫码登录）
weclaw start
```

就这么简单。首次启动时，WeClaw 会：
1. 显示二维码 — 用微信扫码登录
2. 自动检测已安装的 AI Agent（Claude、Codex、Gemini 等）
3. 保存配置到 `~/.weclaw/config.json`
4. 开始接收和回复微信消息

使用 `weclaw login` 可以添加更多微信账号。

### 其他安装方式

```bash
# 通过 Go 安装
go install github.com/fastclaw-ai/weclaw@latest

# 通过 Docker
docker run -it -v ~/.weclaw:/root/.weclaw ghcr.io/fastclaw-ai/weclaw start
```

## 架构

<p align="center">
  <img src="previews/architecture.png" width="600" />
</p>

**Agent 接入模式：**

| 模式 | 工作方式 | 支持的 Agent |
|------|---------|-------------|
| ACP  | 长驻子进程，通过 stdio JSON-RPC 通信。速度最快，复用进程和会话。 | Claude, Codex, Kimi, Gemini, Cursor, OpenCode, OpenClaw |
| CLI  | 每条消息启动一个新进程，支持通过 `--resume` 恢复会话。 | Claude (`claude -p`)、Codex (`codex exec`) |
| HTTP | OpenAI 兼容的 Chat Completions API。 | OpenClaw（HTTP 回退） |

同时存在 ACP 和 CLI 时，自动优先选择 ACP。

## 聊天命令

在微信中发送以下命令：

| 命令 | 说明 |
|------|------|
| `你好` | 发送给默认 Agent |
| `/codex 写一个排序函数` | 发送给指定 Agent |
| `/cc 解释一下这段代码` | 通过别名发送 |
| `/claude` | 切换默认 Agent 为 Claude |
| `/status` | 查看当前 Agent 信息 |

### 快捷别名

| 别名 | Agent |
|------|-------|
| `/cc` | Claude |
| `/cx` | Codex |
| `/cs` | Cursor |
| `/km` | Kimi |
| `/gm` | Gemini |
| `/ocd` | OpenCode |
| `/oc` | OpenClaw |

切换默认 Agent 会写入配置文件，重启后仍然生效。

## 主动推送消息

无需等待用户发消息，主动向微信用户推送消息。

**命令行：**

```bash
weclaw send --to "user_id@im.wechat" --text "你好，来自 weclaw"
```

**HTTP API**（`weclaw start` 运行时，默认监听 `127.0.0.1:18011`）：

```bash
curl -X POST http://127.0.0.1:18011/api/send \
  -H "Content-Type: application/json" \
  -d '{"to": "user_id@im.wechat", "text": "你好，来自 weclaw"}'
```

设置 `WECLAW_API_ADDR` 环境变量可更改监听地址（如 `0.0.0.0:18011`）。

## 配置

配置文件路径：`~/.weclaw/config.json`

```json
{
  "default_agent": "claude",
  "agents": {
    "claude": {
      "type": "acp",
      "command": "/usr/local/bin/claude-agent-acp",
      "model": "sonnet"
    },
    "codex": {
      "type": "cli",
      "command": "/usr/local/bin/codex"
    },
    "openclaw": {
      "type": "http",
      "endpoint": "https://api.example.com/v1/chat/completions",
      "api_key": "sk-xxx",
      "model": "openclaw:main"
    }
  }
}
```

环境变量：
- `WECLAW_DEFAULT_AGENT` — 覆盖默认 Agent
- `OPENCLAW_GATEWAY_URL` — OpenClaw HTTP 回退地址
- `OPENCLAW_GATEWAY_TOKEN` — OpenClaw API Token

## 后台运行

```bash
# 启动（默认后台运行）
weclaw start

# 查看状态
weclaw status

# 停止
weclaw stop

# 前台运行（调试用）
weclaw start -f
```

日志输出到 `~/.weclaw/weclaw.log`。

### 系统服务（开机自启）

**macOS (launchd)：**

```bash
cp service/com.fastclaw.weclaw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.fastclaw.weclaw.plist
```

**Linux (systemd)：**

```bash
sudo cp service/weclaw.service /etc/systemd/system/
sudo systemctl enable --now weclaw
```

## Docker

```bash
# 构建
docker build -t weclaw .

# 镜像内置工具
docker run --rm --entrypoint sh weclaw -lc 'weclaw version && claude --version && codex --version && gemini --version && opencode --version'

# 登录（交互式，扫描二维码）
docker run --rm -it \
  -v ~/.weclaw:/root/.weclaw \
  -v ~/.gemini:/root/.gemini \
  weclaw login

# 前台运行，并持久化 WeClaw 和 Gemini 状态
docker run --rm -it \
  -v ~/.weclaw:/root/.weclaw \
  -v ~/.gemini:/root/.gemini \
  weclaw start

# 使用 HTTP Agent 回退并后台运行
docker run -d --name weclaw \
  -v ~/.weclaw:/root/.weclaw \
  -v ~/.gemini:/root/.gemini \
  -e OPENCLAW_GATEWAY_URL=https://api.example.com \
  -e OPENCLAW_GATEWAY_TOKEN=sk-xxx \
  weclaw

# 查看日志
docker logs -f weclaw

# 停止并删除容器
docker rm -f weclaw
```

`docker-compose.example.yml` 也提供了同样的持久化目录和可选的
OpenClaw gateway 环境变量。默认会把状态保存在当前目录的 `./.weclaw`
和 `./.gemini`；如果你想改成 `~/.weclaw` 这类绝对路径，可以设置
`WECLAW_CONFIG_DIR` / `GEMINI_CONFIG_DIR`：

```bash
# 复制示例文件；如果你使用 OpenClaw HTTP 回退，再按需填写环境变量
cp docker-compose.example.yml docker-compose.yml

# 可选：把状态目录改到 home 目录，而不是仓库当前目录
export WECLAW_CONFIG_DIR="$HOME/.weclaw"
export GEMINI_CONFIG_DIR="$HOME/.gemini"

# 先登录一次，生成 ~/.weclaw/config.json
docker compose run --rm weclaw login

# 后台启动
docker compose up -d

# 查看日志
docker compose logs -f weclaw

# 停止服务
docker compose down
```

> 发布的 Docker 镜像内置了 `weclaw`、`claude`、`codex`、`gemini`、
> `opencode`。像 Cursor、Kimi、以及 OpenClaw gateway 这类仍需额外二进制
> 或外部服务的 Agent，仍需要自行挂载或额外配置。镜像也声明了
> `/root/.gemini` volume，便于按需持久化 Gemini CLI 状态。Dockerfile 现在会
> 在并行构建阶段安装内置 CLI，并在最终运行时镜像中移除 npm，以缩短构建时间并减小镜像体积。

## 发版

```bash
# 打 tag 触发 GitHub Actions 自动构建发版
git tag v0.1.0
git push origin v0.1.0
```

自动构建 `darwin/linux` x `amd64/arm64` 四个平台的二进制，创建 GitHub Release 并上传所有产物和校验文件。
同时会构建一个包含 `weclaw`、`claude`、`codex`、`gemini`、`opencode`
的多架构 GHCR Docker 镜像。

## 开发

```bash
# 热重载
make dev

# 编译
go build -o weclaw .

# 运行
./weclaw start
```

## 许可证

[MIT](LICENSE)
