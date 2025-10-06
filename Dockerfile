# Windows Server 2022 (LTSC) base with PowerShell 7
FROM mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022

# Use PowerShell 7 as the default shell
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

# Ensure TLS protocols are broadly enabled at the OS level (Schannel)
# and set .NET strong crypto and system-default TLS versions
RUN \
  $ErrorActionPreference = 'Stop'; \
  foreach ($proto in 'TLS 1.0','TLS 1.1','TLS 1.2','TLS 1.3') { foreach ($role in 'Client','Server') { $base = "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\$proto\\$role"; if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }; New-ItemProperty -Path $base -Name 'Enabled' -PropertyType DWord -Value 1 -Force | Out-Null; New-ItemProperty -Path $base -Name 'DisabledByDefault' -PropertyType DWord -Value 0 -Force | Out-Null; } }; \
  foreach ($rk in 'HKLM:\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319','HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319') { if (-not (Test-Path $rk)) { New-Item -Path $rk -Force | Out-Null }; New-ItemProperty -Path $rk -Name 'SchUseStrongCrypto' -PropertyType DWord -Value 1 -Force | Out-Null; New-ItemProperty -Path $rk -Name 'SystemDefaultTlsVersions' -PropertyType DWord -Value 1 -Force | Out-Null; }

# Install NuGet CLI and expose on PATH
RUN \
  $ErrorActionPreference = 'Stop'; \
  $nugetDir = 'C:\\tools\\nuget'; New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null; \
  Invoke-WebRequest -UseBasicParsing 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile (Join-Path $nugetDir 'nuget.exe'); \
  & (Join-Path $nugetDir 'nuget.exe') | Select-Object -First 1

# Install .NET SDK (LTS) using official dotnet-install script
RUN \
  $ErrorActionPreference = 'Stop'; \
  $dotnetDir = 'C:\\tools\\dotnet'; New-Item -ItemType Directory -Path $dotnetDir -Force | Out-Null; \
  $script = 'C:\\Windows\\Temp\\dotnet-install.ps1'; \
  Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile $script; \
  & $script -Channel 'LTS' -InstallDir $dotnetDir -NoPath; \
  & (Join-Path $dotnetDir 'dotnet.exe') --info | Select-Object -First 20

# Install Git for Windows (silent)
RUN \
  $ErrorActionPreference = 'Stop'; \
  $gitInstaller = 'C:\\Windows\\Temp\\Git-64-bit.exe'; \
  Invoke-WebRequest -UseBasicParsing 'https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe' -OutFile $gitInstaller; \
  Start-Process -FilePath $gitInstaller -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/SUPPRESSMSGBOXES','/DIR="C:\\Program Files\\Git"' -Wait; \
  & 'C:\\Program Files\\Git\\cmd\\git.exe' --version

# Persist PATH updates for NuGet, .NET, and Git
ENV DOTNET_ROOT="C:\\tools\\dotnet"
ENV PATH="C:\\tools\\nuget;C:\\tools\\dotnet;C:\\Program Files\\Git\\cmd;C:\\Program Files\\PowerShell\\7;${PATH}"

# Trust PSGallery, ensure NuGet provider and PowerShellGet are present and current
RUN \
  $ErrorActionPreference = 'Stop'; \
  if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted }; \
  Install-PackageProvider -Name NuGet -Force -Scope AllUsers; \
  Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber; \
  Import-Module PowerShellGet

# Install commonly used modules including Az
RUN \
  $ErrorActionPreference = 'Stop'; \
  Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope AllUsers; \
  Install-Module -Name Pester -Force -Scope AllUsers; \
  Install-Module -Name SqlServer -Force -Scope AllUsers; \
  Install-Module -Name PSReadLine -Force -Scope AllUsers; \
  Install-Module -Name AzureAD -Force -AllowClobber -Scope AllUsers; \
  Import-Module Az.Accounts -ErrorAction Stop; \
  (Get-Module -ListAvailable Az | Select-Object -First 1).Version | Out-String | Write-Host

# Set an all-users, all-hosts PowerShell profile to prefer system-default TLS
RUN \
  $ErrorActionPreference = 'Stop'; \
  $content = 'try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::SystemDefault -bor 3072 -bor 768 -bor 192 } catch { }'; \
  $profiles = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\profile.ps1','C:\\Program Files\\PowerShell\\7\\profile.ps1'; \
  foreach ($p in $profiles) { $dir = Split-Path -Path $p; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }; Set-Content -Path $p -Value $content -Encoding UTF8 }

# Sensible default working directory
WORKDIR /work

# Default command
ENTRYPOINT ["pwsh", "-NoLogo"]
