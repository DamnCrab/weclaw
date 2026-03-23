FROM golang:1.24-bookworm AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags="-s -w -X github.com/fastclaw-ai/weclaw/cmd.Version=${VERSION}" -o /usr/local/bin/weclaw .

FROM node:20-bookworm-slim

ARG CLAUDE_CODE_VERSION=2.1.81
ARG CODEX_VERSION=0.116.0
ARG GEMINI_CLI_VERSION=0.34.0
ARG OPENCODE_VERSION=1.3.0

ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    "@openai/codex@${CODEX_VERSION}" \
    "@google/gemini-cli@${GEMINI_CLI_VERSION}" \
    "opencode-ai@${OPENCODE_VERSION}" \
    && npm cache clean --force
COPY --from=builder /usr/local/bin/weclaw /usr/local/bin/weclaw

VOLUME /root/.weclaw
ENTRYPOINT ["weclaw"]
CMD ["start"]
