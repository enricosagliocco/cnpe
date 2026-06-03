Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$keySrc = Join-Path $PSScriptRoot "id_rsa"
$keyTmp = [System.IO.Path]::GetTempFileName()

try {
    Copy-Item -Path $keySrc -Destination $keyTmp -Force

    # Restrict key file access to the current user to satisfy OpenSSH checks.
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $account = New-Object System.Security.Principal.NTAccount($currentUser)
    $acl = Get-Acl -Path $keyTmp
    $acl.SetAccessRuleProtection($true, $false)

    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRule($rule)
    }

    $ownerRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $account,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    [void]$acl.AddAccessRule($ownerRule)
    Set-Acl -Path $keyTmp -AclObject $acl

    & ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 "opc@158.180.234.164" -i $keyTmp
}
finally {
    if (Test-Path -Path $keyTmp) {
        Remove-Item -Path $keyTmp -Force
    }
}