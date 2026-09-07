# Security Policy

## Reporting Security Vulnerabilities

Please do not report security vulnerabilities through public GitHub issues. If you discover a security concern regarding secret leakage, authentication bypass, or unsafe default configurations, please report it privately or review local mitigation procedures in `docs/security.md`.

## Core Security Principles

1. **Zero Hardcoded Secrets**: This repository strictly rejects commits containing UUIDs, Reality private keys, Cloudflare tokens, ZeroTier network IDs, or production domain names.
2. **Sanitized Diagnostics**: All diagnostic tools (`check.ps1`, `healthcheck.sh`, `logs.ps1`) sanitize output and will never print full private keys or authorization tokens to terminal stdout or log files.
3. **Least Privilege & Localhost Bindings**: Proxied inbounds (WebSocket and XHTTP) strictly listen on `127.0.0.1` so that traffic can only arrive via authenticated Cloudflare Tunnel or local forwarders.
4. **Credential Rotation**: Procedures for rotating UUIDs and keys upon suspected compromise are documented in `docs/security.md`.
