# Install Ollama (Official Paths)

This reference summarizes official installation paths and a safe first-run sequence before model download monitoring.

## Linux

1. Install with the official script:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

2. Verify:

```bash
ollama --version
```

3. Start service if needed:
- Many Linux setups run Ollama with systemd after install.
- Check status:

```bash
systemctl status ollama
```

- If systemd is unavailable or service is not running, start manually:

```bash
ollama serve
```

## macOS

1. Install from the official app download page (or Homebrew if you prefer package management):
- https://ollama.com/download/mac

2. Launch the app once.

3. Verify in Terminal:

```bash
ollama --version
```

## Windows

1. Install from the official installer page:
- https://ollama.com/download/windows

2. Open a new terminal after installation.

3. Verify:

```powershell
ollama --version
```

## First Pull (Before Monitoring)

Use log files so the monitor can parse progress:

```bash
LOG_DIR=/tmp/ollama-pull-logs
mkdir -p "$LOG_DIR"
ollama pull llama3.2 2>&1 | tee "$LOG_DIR/llama3.2.log"
```

For multiple models, run one pull command per model and store each to a separate `.log` file.

## Sources

- Linux install script docs: https://ollama.com/download/linux
- Official install docs index: https://ollama.readthedocs.io/en/quickstart/
- macOS download: https://ollama.com/download/mac
- Windows download: https://ollama.com/download/windows
- CLI reference (`pull`, `serve`, `list`, etc.): https://ollama.readthedocs.io/en/cli/
