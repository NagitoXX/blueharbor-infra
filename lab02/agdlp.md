# AGDLP on the Finance share (Exercise 2.3)

## What is in place

AGDLP: **A**ccounts go into **G**lobal groups, global groups go into **D**omain **L**ocal groups, and only domain local groups receive **P**ermissions.

```
elaurent, mpetit, lmartin  ->  GG_Finance  ->  DL_FinanceShare_RW  ->  Change (share) + Modify (NTFS)
(empty)                                    ->  DL_FinanceShare_R   ->  Read (share)   + Read & execute (NTFS)
```

| Object | Type | Content / right |
|--------|------|-----------------|
| GG_Finance | Global, security | the three Finance users (selected by `Department -eq 'Finance'`) |
| DL_FinanceShare_RW | Domain local, security | GG_Finance |
| DL_FinanceShare_R | Domain local, security | empty for now |
| Share `\\DC01\Finance` | SMB | Domain Admins Full, DL_FinanceShare_RW Change, DL_FinanceShare_R Read |
| `C:\Shares\Finance` | NTFS | inheritance disabled, BUILTIN\Users removed; DL_FinanceShare_RW Modify, DL_FinanceShare_R Read & execute; Administrators, SYSTEM, CREATOR OWNER kept |

Removing `BUILTIN\Users` matters: on a domain controller, Domain Users is a member of BUILTIN\Users, so without that step every employee could read the folder.

## Checkpoint results

- Effective Access on `C:\Shares\Finance`:
  - **elaurent**: Modify. She can read, write, create and delete, but she cannot use Full control, Change permissions, Take ownership or Delete subfolders and files.
  - **hbernard**: no access. Every right is denied ("limited by Share, File Permissions").
- `Get-SmbShareAccess Finance` lists Domain Admins (Full), DL_FinanceShare_RW (Change) and DL_FinanceShare_R (Read).

## A fourth accountant is hired

Only the user account and one group membership change. The share and the NTFS ACL stay as they are.

```powershell
New-ADUser -Name "First Last" -SamAccountName flast -UserPrincipalName flast@blueharbor.internal `
  -Department Finance -Title Accountant `
  -Path "OU=Finance,OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal" `
  -AccountPassword (Read-Host -AsSecureString "Initial password") -ChangePasswordAtLogon $true -Enabled $true
Add-ADGroupMember -Identity GG_Finance -Members flast
```

The new accountant gets Modify on the share through GG_Finance → DL_FinanceShare_RW. Group membership is read when the user signs in, so the access works from their first logon. A user who is already signed in has to sign out and back in.

## An auditor needs read-only access for one month

The read path already exists: DL_FinanceShare_R has Read on the share and Read & execute in NTFS. It is empty today. Again, nothing changes on the share or the ACL:

1. Create a global group for the role, `GG_Auditors`, in `OU=Groups`, and nest it once in `DL_FinanceShare_R`. The auditor's account is never put directly into the DL group or the ACL.
2. Create the auditor's account with an expiry date one month away, and add it to `GG_Auditors`.

```powershell
$g = "OU=Groups,OU=BlueHarbor,DC=blueharbor,DC=internal"
New-ADGroup -Name GG_Auditors -GroupScope Global -GroupCategory Security -Path $g
Add-ADGroupMember -Identity DL_FinanceShare_R -Members GG_Auditors

New-ADUser -Name "Ext Auditor" -SamAccountName xauditor -UserPrincipalName xauditor@blueharbor.internal `
  -Title "External auditor" -Path "OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal" `
  -AccountExpirationDate (Get-Date).AddMonths(1) `
  -AccountPassword (Read-Host -AsSecureString "Initial password") -ChangePasswordAtLogon $true -Enabled $true
Add-ADGroupMember -Identity GG_Auditors -Members xauditor
```

3. When the month is over, the account expires and can no longer sign in. As cleanup, remove the auditor from GG_Auditors and disable or delete the account. GG_Auditors and its nesting stay ready for the next audit.

An alternative is a membership that removes itself: `Add-ADGroupMember ... -MemberTimeToLive (New-TimeSpan -Days 30)`. It needs the "Privileged Access Management Feature" optional feature, which cannot be turned off once enabled. For a single auditor, the account expiry date is simpler.
