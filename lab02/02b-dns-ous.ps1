# Lab 02 - Exercise 2.2 steps 2 and 3: DNS and OU structure
# Run on DC01 as BLUEHARBOR\Administrator after the forest is created.

# DNS forwarders. The school Wi-Fi blocks public DNS, so its own resolvers come
# first; 1.1.1.1 (workbook value) stays as a fallback for other networks.
Add-DnsServerForwarder -IPAddress 10.96.23.50, 10.96.23.51, 1.1.1.1
Add-DnsServerPrimaryZone -NetworkId "10.10.20.0/24" -ReplicationScope Domain
Add-DnsServerResourceRecordA -ZoneName "blueharbor.internal" -Name "web01" -IPv4Address 10.10.20.20 -CreatePtr
Resolve-DnsName web01.blueharbor.internal
Resolve-DnsName www.microsoft.com

# OU structure
$root = "DC=blueharbor,DC=internal"
New-ADOrganizationalUnit -Name "BlueHarbor" -Path $root
$bh = "OU=BlueHarbor,$root"
"Users","Groups","Servers","Computers","Admins" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path $bh }
"Operations","Finance","IT" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path "OU=Users,$bh" }

Get-ADOrganizationalUnit -Filter * -SearchBase $bh | Select-Object Name, DistinguishedName
