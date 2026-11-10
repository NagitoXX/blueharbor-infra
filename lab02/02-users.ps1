# Lab 02 - Exercise 2.2 steps 4 to 6: import users from C:\Lab\users.csv
# Run on DC01 as BLUEHARBOR\Administrator.
# Safe to run again: an account that already exists (for example after a
# password that failed the complexity rule) gets its password reset and is enabled.

$ErrorActionPreference = "Stop"

New-Item C:\Lab -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot "users.csv") C:\Lab\users.csv -Force

# Domain policy: at least 7 characters, three of upper case, lower case, digit, symbol
$pwd = Read-Host -AsSecureString "Initial password"
Import-Csv C:\Lab\users.csv | ForEach-Object {
  $sam = $_.Sam
  if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
    Set-ADAccountPassword -Identity $sam -Reset -NewPassword $pwd
    Set-ADUser -Identity $sam -ChangePasswordAtLogon $true
    Enable-ADAccount -Identity $sam
  } else {
    New-ADUser -Name "$($_.FirstName) $($_.LastName)" -GivenName $_.FirstName -Surname $_.LastName `
      -SamAccountName $sam -UserPrincipalName "$sam@blueharbor.internal" `
      -Department $_.Department -Title $_.Title `
      -Path "OU=$($_.Department),OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal" `
      -AccountPassword $pwd -ChangePasswordAtLogon $true -Enabled $true
  }
}

Get-ADUser -Filter * -SearchBase "OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal" |
  Select-Object Name, Enabled, DistinguishedName
