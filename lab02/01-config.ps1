# Lab 02 - Exercise 2.1 Part D: DC01 identity
# Run in Windows PowerShell as Administrator on DC01.

# Time zone (Paris)
Set-TimeZone -Id "Romance Standard Time"
Get-TimeZone

# Network adapter (Intel PRO/1000 MT Desktop, alias "Ethernet")
Get-NetAdapter

# Static address on the server VLAN (VirtualBox NAT network BH-SRV)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.10.20.10 -PrefixLength 24 -DefaultGateway 10.10.20.1

# Temporary DNS until DC01 becomes its own DNS server (Exercise 2.2).
# The workbook uses 1.1.1.1, but the school Wi-Fi blocks public DNS (UDP/TCP 53),
# so the network's own resolvers are used instead.
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.96.23.50, 10.96.23.51

Test-NetConnection 1.1.1.1
Resolve-DnsName www.microsoft.com

# Evaluation licence: activate online (required within 10 days)
cscript //nologo C:\Windows\System32\slmgr.vbs /dli
cscript //nologo C:\Windows\System32\slmgr.vbs /ato

# Rename and restart
Rename-Computer -NewName DC01 -Restart
