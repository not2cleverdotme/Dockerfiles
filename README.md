# Windows Server 2022 PowerShell Container

A flexible Windows container image based on Windows Server 2022 + PowerShell 7, optimized for automation, Azure management, and .NET development work.

## Features

- **PowerShell 7** pre-configured and ready to use
- **TLS protocols** enabled at OS level (Schannel) with .NET strong crypto defaults
- **Optional components** via build arguments (see below):
  - NuGet CLI
  - .NET SDK (LTS)
  - Azure PowerShell (Az modules)
  - Pester testing framework
  - SQL Server management module
- **Trusted PowerShell Gallery** and NuGet provider pre-configured
- **Optimized for containers**: telemetry disabled, caches cleaned, minimal bloat

This image is intended for Windows hosts using Windows containers (Hyper-V or process isolation). It is not for Linux hosts.

---

## Build Arguments

Control what gets installed during the build to optimize image size and build time:

| Argument | Default | Description | Size Impact |
|----------|---------|-------------|-------------|
| `INSTALL_DOTNET` | `true` | Install .NET SDK (LTS) | ~500 MB |
| `INSTALL_NUGET` | `true` | Install NuGet CLI tool | ~5 MB |
| `INSTALL_AZ` | `true` | Install Azure PowerShell modules | ~200 MB |
| `INSTALL_PESTER` | `true` | Install Pester testing framework | ~10 MB |
| `INSTALL_SQLSERVER` | `true` | Install SQL Server management module | ~50 MB |

---

## Prerequisites (Windows host)

- Windows Server 2022 (recommended) or Windows 11 with Windows containers
- Choose your host setup:
  - **Windows Server**: enable Hyper-V + Containers roles and install Docker Engine (see below)
  - **Windows 11**: install Docker Desktop, and switch to Windows containers

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

1. Install Docker Desktop for Windows
2. Right-click Docker tray icon → "Switch to Windows containers..."
3. Settings → General: ensure "Use the WSL 2 based engine" is enabled (optional)
4. Pull the base image:

```powershell
docker pull mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022
```

**Note**: Windows container images must match the host OS patch family. Use `--isolation=hyperv` for cross-patch compatibility on client hosts.

---

## Build

### Default build (all features enabled)

```powershell
docker build -t win-pwsh:latest .
```

### Minimal PowerShell-only build

```powershell
docker build `
  --build-arg INSTALL_DOTNET=false `
  --build-arg INSTALL_NUGET=false `
  --build-arg INSTALL_AZ=false `
  --build-arg INSTALL_PESTER=false `
  --build-arg INSTALL_SQLSERVER=false `
  -t win-pwsh:minimal .
```

### Custom build (Azure + .NET only)

```powershell
docker build `
  --build-arg INSTALL_PESTER=false `
  --build-arg INSTALL_SQLSERVER=false `
  -t win-pwsh:azure-dotnet .
```

---

## Run

### Interactive PowerShell session

```powershell
docker run -it --isolation=hyperv win-pwsh:latest
```

### Mount a working folder

```powershell
docker run -it --isolation=hyperv -v C:\work:C:\work -w C:\work win-pwsh:latest
```

### Run a specific script

```powershell
docker run --rm --isolation=hyperv -v C:\scripts:C:\scripts win-pwsh:latest -File C:\scripts\deploy.ps1
```

---

## What's Included

### Base Components (Always Installed)

- Windows Server 2022 LTSC base (`mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022`)
- PowerShell 7.4
- TLS 1.0/1.1/1.2/1.3 enabled for Client/Server in Schannel
- .NET strong crypto registry settings (`SchUseStrongCrypto=1`, `SystemDefaultTlsVersions=1`)
- PowerShellGet updated, PSGallery trusted
- PowerShell profile with TLS preference configuration

### Optional Components (Configurable via Build Args)

#### .NET SDK (`INSTALL_DOTNET=true`)
- Installed to `C:\tools\dotnet`
- `DOTNET_ROOT` environment variable set
- Added to PATH
- Telemetry and first-run experience disabled for faster execution

#### NuGet CLI (`INSTALL_NUGET=true`)
- Installed to `C:\tools\nuget`
- Added to PATH
- Signature validation on download

#### Azure PowerShell (`INSTALL_AZ=true`)
- Complete `Az` module suite
- Ready for Azure automation and management

#### Pester (`INSTALL_PESTER=true`)
- PowerShell testing framework
- Useful for CI/CD pipelines

#### SQL Server Module (`INSTALL_SQLSERVER=true`)
- SQL Server management cmdlets
- Database administration and querying capabilities

---

## Usage Examples

### PowerShell Scripting

```powershell
# Simple script execution
docker run --rm -v C:\scripts:C:\scripts win-pwsh:latest -Command "Get-ChildItem C:\scripts"

# Run tests with Pester
docker run --rm -v C:\project:C:\project -w C:\project win-pwsh:latest -Command "Invoke-Pester"
```

### .NET Development

```powershell
docker run -it -v C:\code:C:\code -w C:\code win-pwsh:latest

# Inside container:
dotnet --info
dotnet new console -n MyApp
cd MyApp
dotnet build
dotnet run
```

### Azure Management

```powershell
docker run -it win-pwsh:latest

# Inside container:
Import-Module Az
Connect-AzAccount
Get-AzResourceGroup
```

### SQL Server Management

```powershell
docker run -it win-pwsh:latest

# Inside container:
Import-Module SqlServer
Invoke-Sqlcmd -ServerInstance "myserver" -Database "mydb" -Query "SELECT @@VERSION"
```

### NuGet Package Management

```powershell
docker run -it win-pwsh:latest

# Inside container:
nuget sources list
nuget install Newtonsoft.Json -Version 13.0.3
```

---

## Environment Variables

The following environment variables are set in the image:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DOTNET_ROOT` | `C:\tools\dotnet` | .NET SDK location |
| `DOTNET_CLI_TELEMETRY_OPTOUT` | `1` | Disable telemetry |
| `DOTNET_SKIP_FIRST_TIME_EXPERIENCE` | `1` | Skip first-run initialization |
| `DOTNET_NOLOGO` | `1` | Suppress .NET logo |
| `PATH` | Includes nuget, dotnet, pwsh | Tool accessibility |

---

## TLS Policy

The image enables TLS 1.0/1.1/1.2/1.3 in Schannel for maximum compatibility and configures .NET to use strong crypto with system default TLS versions.

**To restrict to TLS 1.2/1.3 only**: Edit the Dockerfile and remove TLS 1.0/1.1 configuration from the registry settings.

---

## Optimizations

This Dockerfile includes several optimizations for container efficiency:

1. **Package cache cleanup**: Removes NuGet and PowerShellGet caches after module installation (~100-300 MB saved)
2. **Temp file cleanup**: Clears temporary files after .NET installation (~5-20 MB saved)
3. **Conditional installs**: Only install what you need via build arguments
4. **Telemetry disabled**: Faster .NET operations without telemetry overhead
5. **Progress preference**: Silent progress for faster PowerShell execution

---

## Certificates and Proxies

### Corporate Proxies

Configure proxy environment variables during build or runtime:

```powershell
docker build --build-arg HTTP_PROXY=http://proxy:8080 --build-arg HTTPS_PROXY=http://proxy:8080 -t win-pwsh:latest .
```

### Enterprise CA Certificates

Import root/intermediate certificates during build or mount at runtime:

```dockerfile
# Add to Dockerfile
COPY corporate-ca.crt C:\certs\
RUN Import-Certificate -FilePath C:\certs\corporate-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

---

## Troubleshooting

### "ltsc2022 not found" on Windows 11
- Ensure Docker Desktop is set to Windows containers (not Linux containers)
- Pull the explicit tag: `docker pull mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022`
- Corporate proxy may block MCR; configure proxy or use a mirror

### OS Version Mismatch Errors
- Use `--isolation=hyperv` for cross-patch compatibility
- Or update host to a compatible patch level

### Build Hangs During .NET Installation
- This is normal on first build (first-run experience, even with optimizations)
- Subsequent builds will use Docker cache and be much faster
- The optimizations in this Dockerfile minimize the hang time

### Module Import Failures
- If PSGallery is unavailable at build time, modules won't install
- Rerun `Install-Module` commands inside the running container
- Or configure a private PowerShell repository

### Windows on ARM Devices
- Most Windows container images (including ServerCore LTSC) are amd64 only
- Windows containers on ARM have limited availability

---

## Extending the Image

### Pin Specific Versions

```dockerfile
# Pin .NET version
& $script -Version '8.0.100' -InstallDir $dotnetDir -NoPath

# Pin module versions
Install-Module -Name Az -RequiredVersion 11.0.0 -Force -Scope AllUsers
```

### Add a Non-Admin User

```dockerfile
RUN net user /add myuser mypassword
RUN net localgroup Users myuser /add
USER myuser
```

### Add Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD pwsh -Command "if ((Get-Process pwsh).Count -gt 0) { exit 0 } else { exit 1 }"
```

---

## Image Size Comparison

Approximate final image sizes (uncompressed):

| Configuration | Size |
|---------------|------|
| Base (PowerShell only) | ~5 GB |
| Minimal (all disabled) | ~5 GB |
| Default (all enabled) | ~6.5 GB |
| Azure + .NET only | ~6 GB |

*Windows container images are inherently large due to the Windows Server base layer.*

---

## License

This repository provides a Dockerfile and setup guidance. Software installed inside the image is subject to their respective licenses (Windows container base image, PowerShell, .NET, PowerShell modules, etc.). Review and comply with applicable license terms.

- Windows Server: [Microsoft Software License Terms](https://www.microsoft.com/en-us/licensing/product-licensing/windows-server)
- PowerShell: [MIT License](https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt)
- .NET: [MIT License](https://github.com/dotnet/runtime/blob/main/LICENSE.TXT)
- Azure PowerShell: [Apache 2.0](https://github.com/Azure/azure-powershell/blob/main/LICENSE.txt)