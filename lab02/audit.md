# Directory audit (Exercise 2.5)

Source: [03-audit.ps1](03-audit.ps1), run on DC01 on 10/11/2026 at 14:18. CSV output: [evidence/ad-audit.csv](evidence/ad-audit.csv).

## What the report shows

| Check | Result |
|-------|--------|
| Members of Domain Admins | Administrator only |
| Inactive for 90 days or more | Guest, krbtgt and 7 of the 9 staff accounts (Marc Petit, Lea Martin, Ines Robert, Tom Richard, Sara Durand, Noah Moreau, Lina Simon) |
| Enabled accounts | Administrator and the 9 staff accounts; Guest and krbtgt are disabled |
| PasswordLastSet | empty for the 9 staff accounts (they must change the initial password at next logon); 18:52:39 for Administrator, later than the time the report ran (14:18) |

The two staff accounts that are not inactive (Emma Laurent and Hugo Bernard, 13:46) were never used by a person. Their LastLogonDate comes from the Effective Access check in Exercise 2.3, when Windows built a token for each of them. **No employee has signed in yet.**

## Findings and actions

| # | Finding | Risk | Action |
|---|---------|------|--------|
| 1 | **One shared, built-in admin account.** Domain Admins contains only the built-in Administrator, and every task in Lab 02 was done with it. | No trace of who did what. If this one password leaks, the whole domain is lost. The account cannot be locked out, so it is a known target for password guessing. | Create one named admin account per administrator (for example `adm-sdurand`) in `OU=Admins`, and add those accounts to Domain Admins. PSO-Admins then applies to them. Use them only for administration and keep a normal account for daily work. Keep the built-in Administrator as a break-glass account: long random password in KeePass, not used day to day. |
| 2 | **The Administrator password was not set under the current rules.** It was set when the server was installed, before the 12-character domain policy and before PSO-Admins (16 characters, lockout after 3 attempts). A password policy is only checked when the password changes. Its PasswordLastSet value is also later than the report time, which shows the clock was wrong during the install. | The most powerful account may still have a password shorter than 16 characters, and it will keep it for up to 90 days. A domain controller with a wrong clock breaks Kerberos for every client (5-minute tolerance). | Change the Administrator password now to one of 16+ characters and store it in KeePass. Point the PDC emulator (DC01) at a reliable time source: `w32tm /config /manualpeerlist:"<ntp server>" /syncfromflags:manual /reliable:yes /update`, then check with `w32tm /query /status`. |
| 3 | **Seven enabled accounts have never been used and still have the shared initial password.** They show as inactive, and PasswordLastSet is empty: all nine staff accounts received the same initial password. | Anyone who knows that one initial password can sign in as any colleague who has not signed in yet, and then choose the new password. | Hand out a different initial password per user, through a separate channel. Disable any account still unused after a set number of days (for example 14), and re-enable it on request. Run this audit every month: disable accounts inactive for 90 days and delete them after a further review. |

## Other observations

- **PSO-Admins was created with reversible encryption turned on.** `New-ADFineGrainedPasswordPolicy` turns it on when `-ReversibleEncryptionEnabled` is not given. Admin passwords would then be stored in a form that can be decrypted. It was fixed right away with `Set-ADFineGrainedPasswordPolicy -Identity PSO-Admins -ReversibleEncryptionEnabled $false`; always pass `-ReversibleEncryptionEnabled $false` when creating a PSO.
- **krbtgt** still has the password set when the forest was created (10/11/2026 13:26). That is normal for a new domain. Plan to reset it twice a year, and right away after any suspected compromise.
- **Guest** is disabled, as it should be.
