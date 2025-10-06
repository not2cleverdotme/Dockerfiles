# Windows Server 2022 (LTSC) base with PowerShell 7
FROM mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022

# Use PowerShell 7 as the default shell
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

# Build-time toggles for optional installs
ARG INSTALL_AZ=true
ARG INSTALL_PESTER=true
ARG INSTALL_SQLSERVER=true
ARG INSTALL_PSREADLINE=true
ARG INSTALL_AZUREAD=false

# Ensure TLS protocols are broadly enabled at the OS level (Schannel)
# and set .NET strong crypto and system-default TLS versions
RUN \
  $ErrorActionPreference = 'Stop'; \
  $protocols = 'TLS 1.0','TLS 1.1','TLS 1.2','TLS 1.3'; \
  foreach ($proto in $protocols) { \
    foreach ($role in 'Client','Server') { \
      $key = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\$proto\\$role"; \
      & reg.exe add $key /f | Out-Null; \
      & reg.exe add $key /v Enabled /t REG_DWORD /d 1 /f | Out-Null; \
      & reg.exe add $key /v DisabledByDefault /t REG_DWORD /d 0 /f | Out-Null; \
    } \
  }; \
  & reg.exe add 'HKLM\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319' /f | Out-Null; \
  & reg.exe add 'HKLM\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319' /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null; \
  & reg.exe add 'HKLM\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319' /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null; \
  & reg.exe add 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319' /f | Out-Null; \
  & reg.exe add 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319' /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null; \
  & reg.exe add 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319' /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null

# Common helper: retry wrapper available in subsequent RUN steps via a temporary script
RUN \
  $ErrorActionPreference = 'Stop'; \
  $helper = 'param(); function Invoke-WithRetry { param([ScriptBlock]$Script,[int]$Retries=3,[int]$DelaySeconds=8); for ($i=1; $i -le $Retries; $i++) { try { & $Script; return } catch { if ($i -ge $Retries) { throw }; Start-Sleep -Seconds $DelaySeconds } } }'; \
  $path = 'C:\\Windows\\Temp\\retry.ps1'; \
  Set-Content -Path $path -Value $helper -Encoding UTF8

# Install NuGet CLI and expose on PATH
RUN \
  $ErrorActionPreference = 'Stop'; \
  . 'C:\\Windows\\Temp\\retry.ps1'; \
  $nugetDir = 'C:\\tools\\nuget'; New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null; \
  Invoke-WithRetry { Invoke-WebRequest -UseBasicParsing 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile (Join-Path 'C:\\tools\\nuget' 'nuget.exe') } -Retries 5 -DelaySeconds 10; \
  & (Join-Path $nugetDir 'nuget.exe') | Select-Object -First 1 | Out-String | Write-Host

# Install .NET SDK (LTS) using official dotnet-install script
RUN \
  $ErrorActionPreference = 'Stop'; \
  . 'C:\\Windows\\Temp\\retry.ps1'; \
  $dotnetDir = 'C:\\tools\\dotnet'; New-Item -ItemType Directory -Path $dotnetDir -Force | Out-Null; \
  $script = 'C:\\Windows\\Temp\\dotnet-install.ps1'; \
  Invoke-WithRetry { Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile $script } -Retries 5 -DelaySeconds 10; \
  & $script -Channel 'LTS' -InstallDir $dotnetDir -NoPath; \
  & (Join-Path $dotnetDir 'dotnet.exe') --info | Select-Object -First 20 | Out-String | Write-Host

# Install Git for Windows (silent)
RUN \
  $ErrorActionPreference = 'Stop'; \
  . 'C:\\Windows\\Temp\\retry.ps1'; \
  $gitInstaller = 'C:\\Windows\\Temp\\Git-64-bit.exe'; \
  Invoke-WithRetry { Invoke-WebRequest -UseBasicParsing 'https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe' -OutFile $gitInstaller } -Retries 5 -DelaySeconds 10; \
  Start-Process -FilePath $gitInstaller -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/SUPPRESSMSGBOXES','/DIR="C:\\Program Files\\Git"' -Wait; \
  & 'C:\\Program Files\\Git\\cmd\\git.exe' --version | Out-String | Write-Host

# Persist PATH updates for NuGet, .NET, and Git
ENV DOTNET_ROOT="C:\\tools\\dotnet"
ENV PATH="C:\\\\tools\\nuget;C:\\\\tools\\dotnet;C:\\\\Program Files\\Git\\cmd;C:\\\\Program Files\\PowerShell\\7;${PATH}"

# Trust PSGallery, ensure NuGet provider and PowerShellGet are present and current
RUN \
  $ErrorActionPreference = 'Stop'; \
  . 'C:\\Windows\\Temp\\retry.ps1'; \
  if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted }; \
  Invoke-WithRetry { Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction Stop } -Retries 3 -DelaySeconds 5; \
  Invoke-WithRetry { Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 5; \
  Import-Module PowerShellGet -ErrorAction Stop

# Install commonly used modules (conditionally), including Az
RUN \
  $ErrorActionPreference = 'Stop'; \
  . 'C:\\Windows\\Temp\\retry.ps1'; \
  if ($env:INSTALL_AZ -eq 'true') { Invoke-WithRetry { Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope AllUsers -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 10 }; \
  if ($env:INSTALL_PESTER -eq 'true') { Invoke-WithRetry { Install-Module -Name Pester -Force -Scope AllUsers -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 10 }; \
  if ($env:INSTALL_SQLSERVER -eq 'true') { Invoke-WithRetry { Install-Module -Name SqlServer -Force -Scope AllUsers -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 10 }; \
  if ($env:INSTALL_PSREADLINE -eq 'true') { Invoke-WithRetry { Install-Module -Name PSReadLine -Force -Scope AllUsers -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 10 }; \
  if ($env:INSTALL_AZUREAD -eq 'true') { Invoke-WithRetry { Install-Module -Name AzureAD -Force -Scope AllUsers -AllowClobber -AcceptLicense -ErrorAction Stop } -Retries 3 -DelaySeconds 10 }; \
  if ($env:INSTALL_AZ -eq 'true') { Import-Module Az.Accounts -ErrorAction Stop; (Get-Module -ListAvailable Az | Select-Object -First 1).Version | Out-String | Write-Host }

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
