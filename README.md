# Windows Server 2022 PowerShell Container (TLS, NuGet, Az, .NET)

A Windows container image based on Windows Server 2022 + PowerShell 7 that is preconfigured for secure automation and Azure work:

- TLS protocols enabled at OS level (Schannel) and .NET strong crypto defaults
- NuGet CLI on PATH
- Trusted PowerShell Gallery and NuGet provider
- Core PowerShell modules: Az, Pester, SqlServer, PSReadLine, AzureAD
- .NET SDK (LTS) installed via official dotnet-install

This image is intended for Windows hosts using Windows containers (Hyper‑V or process isolation). It is not for Linux hosts.

---

## Prerequisites (Windows host)

- Windows Server 2022 (recommended) or Windows 11 with Windows containers
- Choose your host setup:
  - Windows Server: enable Hyper‑V + Containers roles and install Docker Engine (see below)
  - Windows 11: install Docker Desktop, and switch to Windows containers

### Windows Server setup

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
Install-WindowsFeature Containers
Restart-Computer

Install-Module -Force -Name DockerMsftProvider
Install-Package -Force -Name docker -ProviderName DockerMsftProvider
Restart-Computer
```

### Windows 11 setup (Docker Desktop)

1) Install Docker Desktop for Windows
2) Right-click Docker tray icon → "Switch to Windows containers..."
3) Settings → General: ensure "Use the WSL 2 based engine" is enabled (optional)
4) Pull a compatible base image (explicit tag):

```powershell
docker pull mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022
```

Notes:
- Windows container images must match the host OS patch family. Prefer `--isolation=hyperv` for cross‑patch compatibility on client hosts.

---

## Build

From a PowerShell prompt on the Windows host:

```powershell
docker build -t win-pwsh-az-dotnet-git:ltsc2022 C:\Users\admin\Documents\Dockerfiles
```

---

## Run

Run an interactive PowerShell session in the container (Hyper‑V isolation recommended):

```powershell
docker run -it --isolation=hyperv --entrypoint pwsh win-pwsh-az-dotnet-git:ltsc2022
```

Mount a working folder:

```powershell
docker run -it --isolation=hyperv -v C:\work:C:\work -w C:\work --entrypoint pwsh win-pwsh-az-dotnet-git:ltsc2022
```

---

## What’s included

- Windows Server 2022 base (PowerShell 7 image: `mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022`)
- TLS 1.0/1.1/1.2/1.3 enabled for Client/Server in Schannel
- .NET registry defaults: `SchUseStrongCrypto=1`, `SystemDefaultTlsVersions=1`
- NuGet CLI installed to `C:\tools\nuget` and on PATH
- PowerShellGet updated, PSGallery trusted
- Modules installed for all users: `Az`, `Pester`, `SqlServer`, `PSReadLine`, `AzureAD`
- .NET SDK (LTS) installed to `C:\tools\dotnet` (`DOTNET_ROOT` set, on PATH)
- PowerShell profile sets broad TLS preference at startup

---

## Usage examples

### .NET

```powershell
dotnet --info
dotnet new console -n Hello
cd Hello
dotnet build
```

### NuGet CLI

```powershell
nuget sources List
nuget install Newtonsoft.Json -Version 13.0.3
```

### PowerShell modules

```powershell
# Azure
Import-Module Az
Connect-AzAccount

# Pester
Invoke-Pester -Version

# SQL Server
Import-Module SqlServer
```

For private feeds over HTTPS, configure credentials (PATs) and enterprise CAs if required.

---

## TLS policy

The image enables TLS 1.0/1.1/1.2/1.3 in Schannel for maximum compatibility and sets .NET to use strong crypto and system default TLS versions.

If you want to restrict to TLS 1.2/1.3, remove TLS 1.0/1.1 enablement in the Dockerfile and keep only 1.2/1.3 keys.

---

## Certificates and proxies

- Corporate proxies: Configure `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` at build/run if needed.
- Enterprise CAs: Import root/intermediate certs during build or mount at runtime and add them to `LocalMachine` stores so PowerShell/.NET trust them.

---

## Troubleshooting

- "ltsc2022 not found" on Windows 11:
  - Ensure Docker Desktop is set to Windows containers (not Linux containers/WSL only)
  - Pull an explicit Windows Server Core tag: `mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022`
  - Corporate proxy may block MCR; configure proxy or pull from a mirror
- OS version mismatch errors:
  - Use `--isolation=hyperv`, or update host to a compatible patch level
- Windows on ARM devices:
  - Many Windows container images (including ServerCore LTSC) are only available for amd64; Windows containers on ARM are limited
- PowerShell module restore:
  - If PSGallery is unavailable at build time, rerun `Install-Module` commands inside the container

---

## Extending the image (optional)

- Pin versions: Pin .NET channel/version and PowerShell module versions for reproducible builds.
- Non-admin user: Add a dedicated user for least-privilege scenarios.
- HEALTHCHECK: Add a simple health check if running services.

---

## License

This repository provides a Dockerfile and setup guidance. Software installed inside the image is subject to their respective licenses (Windows container base image, PowerShell, .NET, PowerShell modules, etc.). Review and comply with applicable license terms.
