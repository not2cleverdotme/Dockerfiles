# Windows Server 2022 PowerShell Container (TLS, NuGet, Az, .NET, Git)

A Windows container image based on Windows Server 2022 + PowerShell 7 that is preconfigured for secure automation and Azure work:

- TLS protocols enabled at OS level (Schannel) and .NET strong crypto defaults
- NuGet CLI on PATH
- Trusted PowerShell Gallery and NuGet provider
- Core PowerShell modules: Az, Pester, SqlServer, PSReadLine, AzureAD
- .NET SDK (LTS) installed via official dotnet-install
- Git for Windows installed and on PATH

This image is intended for Windows hosts using Windows containers (Hyper‑V or process isolation). It is not for Linux hosts.

---

## Prerequisites (Windows host)

- Windows Server 2022 (recommended) or Windows 10/11 with matching Windows container support
- Roles/features and Docker Engine for Windows Server:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
Install-WindowsFeature Containers
Restart-Computer

Install-Module -Force -Name DockerMsftProvider
Install-Package -Force -Name docker -ProviderName DockerMsftProvider
Restart-Computer
```

- Confirm base image availability and OS match:

```powershell
docker pull mcr.microsoft.com/powershell:ltsc2022
```

Notes:
- Windows container images must match the host OS build. Prefer `--isolation=hyperv` for compatibility across patch levels.

---

## Build

From a PowerShell prompt on the Windows host:

```powershell
docker build -t win-pwsh-az-dotnet-git:ltsc2022 C:\Users\admin\Documents\Misc
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

- Windows Server 2022 base (PowerShell 7 image: `mcr.microsoft.com/powershell:ltsc2022`)
- TLS 1.0/1.1/1.2/1.3 enabled for Client/Server in Schannel
- .NET registry defaults: `SchUseStrongCrypto=1`, `SystemDefaultTlsVersions=1`
- NuGet CLI installed to `C:\tools\nuget` and on PATH
- PowerShellGet updated, PSGallery trusted
- Modules installed for all users: `Az`, `Pester`, `SqlServer`, `PSReadLine`, `AzureAD`
- .NET SDK (LTS) installed to `C:\tools\dotnet` (`DOTNET_ROOT` set, on PATH)
- Git for Windows in `C:\Program Files\Git\cmd` and on PATH
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

### Git

```powershell
git --version
git clone https://github.com/contoso/repo.git
```

For private feeds or Git over HTTPS, configure credentials (consider Git Credential Manager or PATs). If your environment uses enterprise CAs, see Certificates below.

---

## TLS policy

The image enables TLS 1.0/1.1/1.2/1.3 in Schannel for maximum compatibility and sets .NET to use strong crypto and system default TLS versions.

If you want to restrict to TLS 1.2/1.3, remove TLS 1.0/1.1 enablement in the Dockerfile and keep only 1.2/1.3 keys.

---

## Certificates and proxies

- Corporate proxies: Configure `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` at build/run if needed.
- Enterprise CAs: Import root/intermediate certs during build or mount at runtime and add them to `LocalMachine` stores so Git/PowerShell/.NET trust them.

---

## Troubleshooting

- OS version mismatch: If `docker run` fails with an OS version error, use `--isolation=hyperv` or rebuild on a host with a matching build.
- PowerShell module restore: If PSGallery is temporarily unavailable, re-run `Install-Module` commands inside the container.
- NuGet private feeds: Add sources and credentials via `nuget sources Add ...` or use `dotnet nuget add source` if using `dotnet` restore.
- Git SSL issues: Import enterprise CA certs into the container and/or configure `git config --system http.sslbackend schannel` (default on Git for Windows) so Windows cert store is used.

---

## Extending the image (optional)

- Pin versions: Pin .NET channel/version, Git version, and PowerShell module versions for reproducible builds.
- Non-admin user: Add a dedicated user for least-privilege scenarios.
- HEALTHCHECK: Add a simple health check if running services.

---

## License

This repository provides a Dockerfile and setup guidance. Software installed inside the image is subject to their respective licenses (Windows container base image, PowerShell, .NET, Git for Windows, PowerShell modules, etc.). Review and comply with applicable license terms.
