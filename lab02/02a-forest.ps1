# Lab 02 - Exercise 2.2 step 1: install AD DS and create the forest
# Run on DC01 as Administrator. The server restarts at the end.

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSForest -DomainName "blueharbor.internal" -DomainNetbiosName "BLUEHARBOR" -InstallDns `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") -Force
