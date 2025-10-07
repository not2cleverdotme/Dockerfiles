# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Enable TLS 1.0, 1.1, 1.2, 1.3 for both Client and Server in Schannel
RUN $protocolRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'; `
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

# Install NuGet (nuget.exe) and add to PATH
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    New-Item -ItemType Directory -Path 'C:\tools\nuget' -Force | Out-Null; `
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile 'C:\tools\nuget\nuget.exe'; `
    setx /M PATH "$($env:PATH);C:\tools\nuget" | Out-Null

# Default command: print NuGet help to verify install
CMD ["C:/tools/nuget/nuget.exe", "help"]
