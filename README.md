# TCP Remote Command Broadcast

> A lightweight proof-of-concept demonstrating raw TCP socket communication, remote command execution, and network stream I/O — built as a cybersecurity portfolio project.

---

## Overview

This project implements a **server/client architecture** over raw TCP sockets where a PowerShell listener accepts inbound connections, executes a received shell command on the host, and returns the output to the caller. A Bash client using `nc` (netcat) drives the interaction from the remote side.

The goal is to demonstrate practical understanding of:

- Low-level TCP socket programming in .NET / PowerShell
- Network stream I/O (readers, writers, buffering)
- Process spawning and stdout redirection
- Defensive coding patterns (timeouts, resource disposal, safe temp paths)
- Basic threat modelling of a command channel

---

## Architecture

```
┌─────────────────────────────────┐         ┌──────────────────────┐
│        Windows Host              │         │    Remote Machine     │
│                                 │         │                      │
│  tcp-listener.ps1               │◄────────│  client.sh  (nc)     │
│  ├── TcpListener (port 4567)    │  TCP    │  ├── send command    │
│  ├── StreamReader / Writer      │  socket │  └── receive output  │
│  ├── cmd.exe (stdout redirect)  │────────►│                      │
│  └── output via stream          │         └──────────────────────┘
└─────────────────────────────────┘
```

**Flow per connection:**

1. Server binds and listens on a configurable port
2. Client connects and sends a single command string (newline-terminated)
3. Server spawns `cmd.exe /c <command>`, captures stdout to a temp file
4. Output is read, sent back over the stream, and the connection closes
5. Server loops and waits for the next client

---

## Components

### `tcp-listener.ps1` — PowerShell server

The server side runs on a Windows host and handles the full receive-execute-respond lifecycle.

**Key implementation details:**

- Uses `System.Net.Sockets.TcpListener` directly — no abstraction layer
- `ReceiveTimeout` set on each accepted client to prevent indefinite blocking on silent connections
- Output file uses `$env:TEMP\tcpout_$PID.txt` — process-scoped temp path avoids collisions
- Temp file cleanup is in a `finally` block, guaranteeing removal even if `Get-Content` throws
- `StreamReader` and `StreamWriter` are explicitly closed in a per-client `finally` block
- Outer `try/catch/finally` ensures the listener is always stopped on exit

```powershell
# Configuration
$remoteIP   = "0.0.0.0"
$port       = 4567
$timeoutMs  = 10000
$outputFile = Join-Path $env:TEMP "tcpout_$PID.txt"
```

---

### `client.sh` — Bash client (netcat)

The client runs on any Unix machine with `nc` available and provides an interactive prompt loop.

**Key implementation details:**

- `nc -q 1` gives the server a 1-second grace period after stdin closes to flush its response before the socket tears down — prevents truncated output
- Each loop iteration is a fresh TCP connection, matching the server's one-command-per-connection design
- `exit` / `quit` cleanly break the loop without leaving a dangling connection

```bash
REMOTE_IP="192.168.1.100"
PORT=4567
```

---

## Skills Demonstrated

| Area | Detail |
|---|---|
| Network programming | Raw TCP socket lifecycle — bind, listen, accept, read, write, close |
| Process management | Spawning child processes with stdout redirection and `WaitForExit()` |
| Stream I/O | `StreamReader` / `StreamWriter` over `NetworkStream`, AutoFlush handling |
| Defensive coding | Timeouts, `finally` cleanup, PID-scoped temp files, explicit disposal |
| Threat modelling | Identifying attack surface: no auth, plaintext channel, single-threaded |
| Cross-platform | PowerShell (.NET) server paired with Bash/netcat client |
| Malware analysis | Static analysis of a PE32 .NET binary using `strings`, `file`, and PE inspection |

---

## Running the Project

### Prerequisites

- Windows machine with PowerShell 5.1+
- Linux/macOS machine with `nc` (netcat) installed
- Both machines on the same network (or VPN)

### Start the server

```powershell
# On the Windows host
.\tcp-listener.ps1
# Output: Listening on 0.0.0.0:4567...
```

### Connect from the client

```bash
# On the remote machine
chmod +x client.sh
./client.sh

> whoami
> ipconfig
> exit
```

---

## Security Considerations

This project intentionally leaves several hardening concerns unaddressed, as it is a proof-of-concept for educational purposes. A production command channel would require:

- **Mutual TLS** — encrypt the transport and authenticate both ends with certificates
- **Command allowlisting** — restrict accepted commands to a defined safe set
- **Authentication token** — shared secret or challenge-response before any command is accepted
- **Audit logging** — append every command and source IP to a tamper-evident log
- **Multi-threading** — use `ThreadPool` or `async`/`await` to serve concurrent clients without blocking

The current design is intentionally minimal to keep the socket and I/O logic readable and unobscured by security scaffolding.

---

## Project Structure

```
.
├── tcp-listener.ps1   # PowerShell TCP server (Windows)
├── client.sh          # Bash netcat client (Linux / macOS)
└── README.md
```

---

## Disclaimer

This project is for **educational and portfolio purposes only**. Run it exclusively in isolated lab environments or networks you own and control. Do not deploy on production systems or public networks.
