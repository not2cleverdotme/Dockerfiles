## Windows Server Core Docker Image with TLS Enabled, NuGet, Az Module, and Azure CLI

This image is based on `mcr.microsoft.com/windows/servercore:ltsc2022` and is intended to run on Windows 11 with Windows containers. It enables all TLS protocol versions in Schannel (Client and Server), installs `nuget.exe` to `C:\tools\nuget`, installs the PowerShell `Az` module, and installs the Azure CLI (`az`).

### Prerequisites
- Windows 11 with Docker Desktop
- Windows containers mode enabled (not Linux containers)
- Matching host/daemon OS version for `ltsc2022`

### Build
```powershell
# From this directory
docker build --no-cache -t win2022:ltsc2022 -f Dockerfile .
```

### Run
```powershell
docker run --rm win2022:ltsc2022
```
The default command prints NuGet help, confirming installation and PATH configuration.

### What this image does
- Enables TLS 1.0, 1.1, 1.2, and 1.3 for both Client and Server via Schannel registry keys.
- Downloads `nuget.exe` to `C:\tools\nuget` and adds it to `PATH`.
- Installs the PowerShell `Az` module from the PowerShell Gallery (PSGallery) for all users. The module is not preloaded during build to keep build times short.
- Installs Azure CLI (`az`) via MSI and adds its bin directory to `PATH`.
- Ensures `powershell.exe` is globally available by appending `C:\Windows\System32\WindowsPowerShell\v1.0` to `PATH`.
- Ensures common module locations are present in `PSModulePath` for `Az` discovery.

### Validate inside the container
```powershell
# Start an interactive PowerShell shell
docker run --rm -it win2022:ltsc2022 powershell

# Check nuget on PATH
nuget help

# Verify TLS registry keys (example for TLS 1.2 Client)
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' |
  Select-Object Enabled, DisabledByDefault

# Import Az (installed but not preloaded during build) and verify
Import-Module Az
Get-Module Az | Select-Object Name, Version | Format-Table -AutoSize

# Verify Azure CLI on PATH
az --version
```
Expected TLS values: `Enabled = 1`, `DisabledByDefault = 0`.

### Notes
- Some Windows builds may not fully support TLS 1.3 via Schannel; keys are created for consistency, but behavior can depend on the base OS image.
- If corporate proxies/SSL inspection are present, `Invoke-WebRequest` may need additional parameters or proxy env vars during build.
- The `Az` module install is non-interactive; PSGallery is trusted and the NuGet provider is ensured. Import at runtime with `Import-Module Az`.

### Troubleshooting
- Ensure Docker is in Windows containers mode.
- Image OS must be compatible with the host (e.g., `ltsc2022`).
- If `nuget`, `az`, or `powershell` are not found, confirm `ENV PATH` is in effect or re-run a new container session.
- If TLS keys appear missing, rebuild with `--no-cache` to force the registry step to execute.
