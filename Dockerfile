FROM golang:1.24-bookworm AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags="-s -w -X github.com/fastclaw-ai/weclaw/cmd.Version=${VERSION}" -o /usr/local/bin/weclaw .

FROM node:20-bookworm-slim AS cli-base

# Pin CLI versions for reproducible image builds. Update these ARG defaults
# when intentionally upgrading bundled tools.
ARG CLAUDE_CODE_VERSION=2.1.81
ARG CODEX_VERSION=0.116.0
ARG GEMINI_CLI_VERSION=0.34.0
ARG OPENCODE_VERSION=1.3.0

ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_CACHE=/tmp/.npm \
    NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

FROM cli-base AS claude-cli
ARG CLAUDE_CODE_VERSION
RUN npm install -g --prefix /opt/claude --no-audit --prefer-offline "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/.npm

FROM cli-base AS codex-cli
ARG CODEX_VERSION
RUN npm install -g --prefix /opt/codex --no-audit --prefer-offline "@openai/codex@${CODEX_VERSION}" \
    && rm -rf /tmp/.npm

FROM cli-base AS gemini-cli
ARG GEMINI_CLI_VERSION
RUN npm install -g --prefix /opt/gemini --no-audit --prefer-offline "@google/gemini-cli@${GEMINI_CLI_VERSION}" \
    && rm -rf /tmp/.npm

FROM cli-base AS opencode-cli
ARG OPENCODE_VERSION
RUN npm install -g --prefix /opt/opencode --no-audit --prefer-offline "opencode-ai@${OPENCODE_VERSION}" \
    && rm -rf /tmp/.npm

FROM node:20-bookworm-slim

ENV NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/lib/node_modules/npm \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

COPY --from=claude-cli /opt/claude /opt/claude
COPY --from=codex-cli /opt/codex /opt/codex
COPY --from=gemini-cli /opt/gemini /opt/gemini
COPY --from=opencode-cli /opt/opencode /opt/opencode

RUN ln -s /opt/claude/bin/claude /usr/local/bin/claude \
    && ln -s /opt/codex/bin/codex /usr/local/bin/codex \
    && ln -s /opt/gemini/bin/gemini /usr/local/bin/gemini \
    && ln -s /opt/opencode/bin/opencode /usr/local/bin/opencode \
    && mkdir -p /root/.weclaw /root/.gemini
COPY --from=builder /usr/local/bin/weclaw /usr/local/bin/weclaw

VOLUME ["/root/.weclaw", "/root/.gemini"]
ENTRYPOINT ["weclaw"]
CMD ["start"]
