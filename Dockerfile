FROM mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2016

ENV SP_VERSION=3.1.0.1
ARG TIERVERSION=20200417

RUN powershell [Environment]::SetEnvironmentVariable('SP_VERSION','%SP_VERSION%', [System.EnvironmentVariableTarget]::Machine )

#install shibb sp
RUN powershell (new-object System.Net.WebClient).Downloadfile('https://shibboleth.net/downloads/service-provider/latest/win64/shibboleth-sp-%SP_VERSION%-win64.msi', 'C:\shibboleth-sp-%SP_VERSION%-win64.msi')
RUN powershell If ((Get-FileHash C:\shibboleth-sp-%SP_VERSION%-win64.msi -Algorithm SHA256).Hash.ToLower() -eq '1f9138254da24771073f807c8f915d76e5070df8dcf4db885be830808b21084c') { ` \
		start-process -filepath c:\windows\system32\msiexec.exe -passthru -wait -argumentlist '/i','C:\shibboleth-sp-%SP_VERSION%-win64.msi','/qn' ` \
		       } Else { throw 'bad hash comparison on SP download' }
RUN del C:\shibboleth-sp-%SP_VERSION%-win64.msi
RUN C:\Windows\System32\inetsrv\appcmd install module /name:ShibNative32 /image:"c:\opt\shibboleth-sp\lib\shibboleth\iis7_shib.dll" /precondition:bitness32
RUN C:\Windows\System32\inetsrv\appcmd install module /name:ShibNative /image:"c:\opt\shibboleth-sp\lib64\shibboleth\iis7_shib.dll" /precondition:bitness64
COPY container_files/attribute-map.xml c:/opt/shibboleth-sp/etc/shibboleth/

#add ASP.NET and IIS svc monitor
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]	
RUN Add-WindowsFeature Web-WebServer; ` \
    Add-WindowsFeature Web-Net-Ext45; ` \
    Add-WindowsFeature Web-Asp-Net45; ` \
    Remove-Item -Recurse C:\inetpub\wwwroot\*; ` \
    Invoke-WebRequest -Uri https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe -OutFile C:\ServiceMonitor.exe

#healthcheck command for container state reporting
HEALTHCHECK --interval=1m --timeout=30s \
  CMD powershell [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; (new-object System.Net.WebClient).DownloadString("http://127.0.0.1/Shibboleth.sso/Status")  

#start both shibd and IIS
COPY container_files/start.bat c:/
ENTRYPOINT ["C:\\start.bat"]

