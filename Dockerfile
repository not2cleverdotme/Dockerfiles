# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Enable TLS 1.0, 1.1, 1.2, 1.3 for both Client and Server in Schannel
RUN $protocolRoot = 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols'; `
    New-Item -Path $protocolRoot -Force | Out-Null; `
    $protocols = 'TLS 1.0','TLS 1.1','TLS 1.2','TLS 1.3'; `
    foreach ($p in $protocols) { `
      foreach ($r in 'Client','Server') { `
        $base = Join-Path (Join-Path $protocolRoot $p) $r; `
        if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }; `
        New-ItemProperty -Path $base -Name 'Enabled' -PropertyType DWord -Value 1 -Force | Out-Null; `
        New-ItemProperty -Path $base -Name 'DisabledByDefault' -PropertyType DWord -Value 0 -Force | Out-Null; `
      } `
    }

# Install NuGet (nuget.exe)
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    New-Item -ItemType Directory -Path 'C:\\tools\\nuget' -Force | Out-Null; `
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile 'C:\\tools\\nuget\\nuget.exe'

# Install PowerShell Az module (trust PSGallery, ensure NuGet provider)
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null }; `
    if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted }; `
    Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force -AllowClobber -Confirm:$false

# Ensure PowerShell and nuget are on PATH for build and runtime
ENV PATH=C:\\Windows\\System32\\WindowsPowerShell\\v1.0;C:\\tools\\nuget;%PATH%

# Default command: print NuGet help to verify install
CMD ["C:/tools/nuget/nuget.exe", "help"]
