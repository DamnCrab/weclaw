package agent

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCLIAgentCodexExecArgsIncludesSkipGitRepoCheck(t *testing.T) {
	agent := &CLIAgent{}

	got := agent.codexExecArgs("hello")

	want := []string{"exec", "--skip-git-repo-check", "hello"}
	if len(got) != len(want) {
		t.Fatalf("got %d args, want %d: %v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("arg %d = %q, want %q (full args: %v)", i, got[i], want[i], got)
		}
	}
}

func TestCLIAgentCodexExecArgsIncludesModelWhenConfigured(t *testing.T) {
	agent := &CLIAgent{model: "gpt-5"}

	got := agent.codexExecArgs("hello")

	want := []string{"exec", "--skip-git-repo-check", "hello", "--model", "gpt-5"}
	if len(got) != len(want) {
		t.Fatalf("got %d args, want %d: %v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("arg %d = %q, want %q (full args: %v)", i, got[i], want[i], got)
		}
	}
}

func TestCLIAgentChatCodexPassesSkipGitRepoCheck(t *testing.T) {
	dir := t.TempDir()
	argsFile := filepath.Join(dir, "args.txt")
	scriptPath := filepath.Join(dir, "codex")
	script := "#!/bin/sh\nprintf '%s\n' \"$@\" >" + shellQuote(argsFile) + "\nprintf 'ok from codex\\n'\n"
	if err := os.WriteFile(scriptPath, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake codex: %v", err)
	}

	agent := &CLIAgent{command: scriptPath}

	got, err := agent.chatCodex(context.Background(), "hello")
	if err != nil {
		t.Fatalf("chatCodex returned error: %v", err)
	}
	if got != "ok from codex" {
		t.Fatalf("chatCodex returned %q, want %q", got, "ok from codex")
	}

	data, err := os.ReadFile(argsFile)
	if err != nil {
		t.Fatalf("read args file: %v", err)
	}

	args := strings.Split(strings.TrimSpace(string(data)), "\n")
	want := []string{"exec", "--skip-git-repo-check", "hello"}
	if len(args) != len(want) {
		t.Fatalf("got %d args, want %d: %v", len(args), len(want), args)
	}
	for i := range want {
		if args[i] != want[i] {
			t.Fatalf("arg %d = %q, want %q (full args: %v)", i, args[i], want[i], args)
		}
	}
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}
