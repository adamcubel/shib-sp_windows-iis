FROM microsoft/iis

ENV SP_VERSION=3.0.4.0
RUN powershell [Environment]::SetEnvironmentVariable('SP_VERSION','%SP_VERSION%', [System.EnvironmentVariableTarget]::Machine )

#install shibb sp
RUN powershell (new-object System.Net.WebClient).Downloadfile('https://shibboleth.net/downloads/service-provider/latest/win64/shibboleth-sp-%SP_VERSION%-win64.msi', 'C:\shibboleth-sp-%SP_VERSION%-win64.msi')
RUN powershell If ((Get-FileHash C:\shibboleth-sp-%SP_VERSION%-win64.msi -Algorithm SHA1).Hash.ToLower() -eq '76e8899b6aa353290c1483f62ff3bf6753919c2c') { ` \
		start-process -filepath c:\windows\system32\msiexec.exe -passthru -wait -argumentlist '/i','C:\shibboleth-sp-%SP_VERSION%-win64.msi','/qn' ` \
		       } Else { throw 'bad hash comparison on SP download' }
RUN del C:\shibboleth-sp-%SP_VERSION%-win64.msi
RUN C:\Windows\System32\inetsrv\appcmd install module /name:ShibNative32 /image:"c:\opt\shibboleth-sp\lib\shibboleth\iis7_shib.dll" /precondition:bitness32
RUN C:\Windows\System32\inetsrv\appcmd install module /name:ShibNative /image:"c:\opt\shibboleth-sp\lib64\shibboleth\iis7_shib.dll" /precondition:bitness64
COPY container_files/attribute-map.xml c:/opt/shibboleth-sp/etc/shibboleth/

#add ASP.NET and IIS svc monitor
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]	
RUN Add-WindowsFeature Web-Server; ` \
    Add-WindowsFeature NET-Framework-45-ASPNET; ` \
    Add-WindowsFeature Web-Asp-Net45; ` \
    Remove-Item -Recurse C:\inetpub\wwwroot\*; ` \
    Invoke-WebRequest -Uri https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe -OutFile C:\ServiceMonitor.exe

#healthcheck command for container state reporting
HEALTHCHECK --interval=1m --timeout=30s \
  CMD powershell [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; (new-object System.Net.WebClient).DownloadString("http://127.0.0.1/Shibboleth.sso/Status")  

#start both shibd and IIS
COPY container_files/start.bat c:/
ENTRYPOINT ["C:\\start.bat"]

