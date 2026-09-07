# Contributing Guidelines

Thank you for contributing to Mobile Network Resilience!

## Development & Testing Rules

1. **Verify Before Claiming**: Do not submit pull requests with unchecked test assertions. If a script or test was executed on Linux, mark it as tested on Linux. If a Windows script was checked for syntax only without live Windows API invocation, specify `SYNTAX VERIFIED - REQUIRES WINDOWS HOST`.
2. **Never Commit Secrets**: Any PR introducing plaintext UUIDs, keys, or tokens in `.json`, `.yml`, or documentation examples will be rejected immediately.
3. **Keep Transports Justified**: Every inbound transport profile must serve a distinct network resilience role. Avoid adding esoteric protocols without concrete proof of compatibility with mobile clients (HAPP) and underlying infrastructure.
4. **Shell & Script Standards**:
   - Shell scripts must pass `bash -n` and adhere to POSIX / portable bash standards.
   - PowerShell scripts must enforce `$ErrorActionPreference = "Stop"`, handle quoting properly, check for Administrator elevation where needed, and provide clear error messages.
