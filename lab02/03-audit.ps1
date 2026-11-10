# Lab 02 - Exercise 2.5 step 5: directory audit report
# Run on DC01 as BLUEHARBOR\Administrator. CSV output: C:\Lab\ad-audit.csv
# (a copy of the CSV is kept in lab02/evidence/ad-audit.csv)

New-Item C:\Lab -ItemType Directory -Force | Out-Null

"== Members of Domain Admins =="
Get-ADGroupMember "Domain Admins" | Select-Object Name, SamAccountName | Format-Table -AutoSize

"== User accounts inactive for 90 days or more =="
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly | Select-Object Name | Format-Table -AutoSize

"== All user accounts =="
Get-ADUser -Filter * -Properties LastLogonDate, PasswordLastSet, Enabled |
  Select-Object Name, Enabled, LastLogonDate, PasswordLastSet |
  Export-Csv C:\Lab\ad-audit.csv -NoTypeInformation
Import-Csv C:\Lab\ad-audit.csv | Format-Table -AutoSize
"Report written to C:\Lab\ad-audit.csv"
