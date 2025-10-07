# Windows Server 2022 (LTSC) base with PowerShell 7
FROM mcr.microsoft.com/powershell:7.4-windowsservercore-ltsc2022

# Build-time toggles for optional installs
ARG INSTALL_DOTNET=true
ARG INSTALL_NUGET=true
ARG INSTALL_AZ=true
ARG INSTALL_PESTER=true
ARG INSTALL_SQLSERVER=true

# Ensure TLS protocols are broadly enabled at the OS level (Schannel)
# and set .NET strong crypto and system-default TLS versions
RUN powershell -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; $protocols=@('TLS 1.0','TLS 1.1','TLS 1.2','TLS 1.3'); foreach ($proto in $protocols) { foreach ($role in @('Client','Server')) { $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\{1}' -f $proto,$role; if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }; New-ItemProperty -Path $base -Name Enabled -PropertyType DWord -Value 1 -Force | Out-Null; New-ItemProperty -Path $base -Name DisabledByDefault -PropertyType DWord -Value 0 -Force | Out-Null } }; foreach ($rk in @('HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319','HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319')) { if (-not (Test-Path $rk)) { New-Item -Path $rk -Force | Out-Null }; New-ItemProperty -Path $rk -Name SchUseStrongCrypto -PropertyType DWord -Value 1 -Force | Out-Null; New-ItemProperty -Path $rk -Name SystemDefaultTlsVersions -PropertyType DWord -Value 1 -Force | Out-Null }"

# Install NuGet CLI and expose on PATH (conditionally)
RUN ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-NoLogo","-NoProfile","-Command","$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; if ($env:INSTALL_NUGET -eq 'true') { $nugetDir = 'C:\\tools\\nuget'; New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null; $url = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'; $out = Join-Path $nugetDir 'nuget.exe'; $downloaded = $false; try { Invoke-WebRequest -UseBasicParsing $url -OutFile $out -ErrorAction Stop; $downloaded = $true; } catch { Write-Warning 'NuGet download failed due to TLS/certificate. Falling back to -SkipCertificateCheck with signature validation.'; }; if (-not $downloaded) { Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck $url -OutFile $out -ErrorAction Stop; $sig = Get-AuthenticodeSignature -FilePath $out; if ($sig.Status -ne 'Valid' -or -not ($sig.SignerCertificate.Subject -like '*Microsoft*')) { Remove-Item -Path $out -Force -ErrorAction SilentlyContinue; throw ('NuGet.exe signature validation failed: ' + $sig.Status) } }; & $out | Select-Object -First 1 | Out-String | Write-Host; Write-Host 'NuGet CLI installed successfully' } else { Write-Host 'Skipping NuGet CLI installation (INSTALL_NUGET=false)' }"]

# Install .NET SDK (LTS) using official dotnet-install script (conditionally)
RUN ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-NoLogo","-NoProfile","-Command","$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; if ($env:INSTALL_DOTNET -eq 'true') { $dotnetDir = 'C:\\tools\\dotnet'; New-Item -ItemType Directory -Path $dotnetDir -Force | Out-Null; $script = 'C:\\Windows\\Temp\\dotnet-install.ps1'; $url = 'https://dot.net/v1/dotnet-install.ps1'; try { curl.exe -L $url -o $script; } catch { Write-Warning 'curl.exe failed; falling back to Invoke-WebRequest -SkipCertificateCheck'; Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck $url -OutFile $script -ErrorAction Stop; }; & $script -Channel 'LTS' -InstallDir $dotnetDir -NoPath; $env:DOTNET_CLI_TELEMETRY_OPTOUT='1'; $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'; $env:DOTNET_NOLOGO='1'; & (Join-Path $dotnetDir 'dotnet.exe') --info | Select-Object -First 20 | Out-String | Write-Host; Remove-Item -Path $script -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue; Write-Host '.NET SDK installed successfully' } else { Write-Host 'Skipping .NET SDK installation (INSTALL_DOTNET=false)' }"]

# Persist PATH updates for NuGet and .NET, and optimize .NET CLI behavior
ENV DOTNET_ROOT="C:\\tools\\dotnet"
ENV PATH="C:\\tools\\nuget;C:\\tools\\dotnet;C:\\Program Files\\PowerShell\\7;${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="1"
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1"
ENV DOTNET_NOLOGO="1"

# Trust PSGallery, ensure NuGet provider and PowerShellGet are present and current
RUN ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-NoLogo","-NoProfile","-Command","$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; try { Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop } catch { }; Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers; Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber -AcceptLicense; Import-Module PowerShellGet -ErrorAction Stop"]

# Install commonly used modules (conditionally), including Az
RUN ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-NoLogo","-NoProfile","-Command","$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; function InstallWithRetry { param([string]$Name,[hashtable]$Params); for($i=0;$i -lt 3;$i++){ try { Install-Module -Name $Name @Params; return } catch { Start-Sleep -Seconds 8 } }; throw 'Failed to install module' }; if ($env:INSTALL_AZ -eq 'true') { InstallWithRetry 'Az' @{ Repository='PSGallery'; Force=$true; AllowClobber=$true; Scope='AllUsers'; AcceptLicense=$true } }; if ($env:INSTALL_PESTER -eq 'true') { InstallWithRetry 'Pester' @{ Force=$true; Scope='AllUsers'; AcceptLicense=$true } }; if ($env:INSTALL_SQLSERVER -eq 'true') { InstallWithRetry 'SqlServer' @{ Force=$true; Scope='AllUsers'; AcceptLicense=$true } }; if ($env:INSTALL_AZ -eq 'true') { Import-Module Az.Accounts -ErrorAction Stop; (Get-Module -ListAvailable Az | Select-Object -First 1).Version | Out-String | Write-Host }; Write-Host 'Cleaning up package manager caches...'; Get-ChildItem -Path \"$env:LOCALAPPDATA\\NuGet\\Cache\" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue; Get-ChildItem -Path \"$env:ProgramData\\Microsoft\\Windows\\PowerShell\\PowerShellGet\" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue"]

# Set an all-users, all-hosts PowerShell profile to prefer system-default TLS
RUN ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-NoLogo","-NoProfile","-Command","$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $content = 'try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::SystemDefault -bor 3072 -bor 768 -bor 192 } catch { }'; $profiles = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\profile.ps1','C:\\Program Files\\PowerShell\\7\\profile.ps1'; foreach ($p in $profiles) { $dir = Split-Path -Path $p; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }; Set-Content -Path $p -Value $content -Encoding UTF8 }"]

# Sensible default working directory
WORKDIR /work

# Default command
ENTRYPOINT ["C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo"]
