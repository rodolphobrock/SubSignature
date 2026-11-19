[CmdletBinding()]
param(
    [string]$Title = 'SubSignature LDAP JIT test',
    [string]$AppBranch = 'custom/release'
)

$ErrorActionPreference = 'Stop'
$playgroundId = $null
$runDirectory = $null

function Invoke-Labctl {
    param([Parameter(Mandatory)][string[]]$Arguments)

    & labctl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "labctl command failed: $($Arguments -join ' ')"
    }
}

function New-TestPassword {
    $bytes = [byte[]]::new(24)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return 'Aa1-' + [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', 'A').Replace('/', 'B')
}

try {
    if (-not (Get-Command labctl -ErrorAction SilentlyContinue)) {
        throw 'Install labctl and run labctl auth login before starting this test.'
    }

    if ($AppBranch -notmatch '^[A-Za-z0-9._/-]+$') {
        throw 'AppBranch may contain only letters, numbers, dots, underscores, slashes, and hyphens.'
    }

    $sshIdentity = Join-Path $HOME '.ssh\iximiuz_labs_user'
    if (-not (Test-Path $sshIdentity) -or -not (Test-Path "$sshIdentity.pub")) {
        throw 'The Iximiuz SSH key is missing. Run labctl auth login, then retry.'
    }

    $sambaImage = 'nowsci/samba-domain@sha256:1332280d188fa374afa26a7858706032c7e938b19ce16da4c443181bc396a83c'
    $playgroundOutput = & labctl playground start docker --as-free-tier-user --title $Title --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not start the free-tier Docker playground.'
    }
    $playgroundId = (@($playgroundOutput) -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($playgroundId)) {
        throw 'labctl started no playground or returned an empty ID.'
    }

    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'pull', $sambaImage)

    $domainPassword = New-TestPassword
    $servicePassword = New-TestPassword
    $activePassword = New-TestPassword
    $disabledPassword = New-TestPassword

    Invoke-Labctl @(
        'ssh', $playgroundId, '--', 'docker', 'run', '-d',
        '--name', 'samba-ad',
        '--hostname', 'dc1',
        '-e', 'DOMAIN=TESTE.LOCAL',
        '-e', "DOMAINPASS=$domainPassword",
        '-p', '127.0.0.1:1636:636',
        '--privileged',
        $sambaImage
    )

    $domainReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $null = & labctl ssh $playgroundId -- docker exec samba-ad samba-tool domain info 127.0.0.1 2>$null
        if ($LASTEXITCODE -eq 0) {
            $domainReady = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $domainReady) {
        throw 'Samba AD did not finish provisioning within 2 minutes.'
    }

    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'exec', 'samba-ad', 'samba-tool', 'user', 'create', 'svc-subsig', $servicePassword)
    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'exec', 'samba-ad', 'samba-tool', 'user', 'create', 'jit-active', $activePassword, '--given-name', 'JIT', '--surname', 'Active', '--mail-address', 'jit-active@teste.local')
    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'exec', 'samba-ad', 'samba-tool', 'user', 'create', 'jit-disabled', $disabledPassword, '--given-name', 'JIT', '--surname', 'Disabled', '--mail-address', 'jit-disabled@teste.local')
    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'exec', 'samba-ad', 'samba-tool', 'user', 'disable', 'jit-disabled')
    Invoke-Labctl @('ssh', $playgroundId, '--', 'docker', 'cp', 'samba-ad:/var/lib/samba/private/tls/ca.pem', '/home/laborant/samba-ad-ca.pem')

    $remoteSetup = @'
#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl git php-cli php-ldap php-mbstring php-sqlite3 php-xml php-zip

app_dir=/home/laborant/SubSignature
git clone --single-branch --branch '__APP_BRANCH__' https://github.com/rodolphobrock/SubSignature.git "$app_dir"
sudo chown laborant:laborant /home/laborant/samba-ad-ca.pem

if ! grep -Fxq '127.0.0.1 dc1.teste.local' /etc/hosts; then
    printf '%s\n' '127.0.0.1 dc1.teste.local' | sudo tee -a /etc/hosts >/dev/null
fi

nohup php -S 127.0.0.1:8100 -t "$app_dir/public_html" >/tmp/subsignature-php-server.log 2>&1 </dev/null &
echo "$!" >/tmp/subsignature-php-server.pid

for attempt in $(seq 1 60); do
    if curl --fail --silent http://127.0.0.1:8100/install.php >/dev/null; then
        exit 0
    fi
    sleep 1
done

cat /tmp/subsignature-php-server.log >&2
echo 'SubSignature did not become ready within 60 seconds.' >&2
exit 1
'@
    $remoteSetup = $remoteSetup.Replace('__APP_BRANCH__', $AppBranch)
    $remoteSetup = ($remoteSetup -replace "`r`n?", "`n") + "`n"
    $remoteSetup | & labctl ssh $playgroundId -- sudo tee /tmp/subsignature-iximiuz-setup.sh | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not transfer the SubSignature setup script to the playground.'
    }
    Invoke-Labctl @('ssh', $playgroundId, '--', 'bash', '/tmp/subsignature-iximiuz-setup.sh')

    $runDirectory = Join-Path $env:TEMP "SubSignature-Iximiuz-$playgroundId"
    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
    $knownHostsFile = Join-Path $runDirectory 'known_hosts'

    Write-Host ''
    Write-Host 'The private free-tier playground, Samba AD, and SubSignature are ready.'
    Write-Host "Playground ID (local only): $playgroundId"
    Write-Host 'The app and LDAPS listen on playground loopback only; no service port is public.'
    Write-Host ''
    Write-Host 'In a separate terminal, start the private SSH proxy:'
    Write-Host "  labctl ssh-proxy $playgroundId --address 127.0.0.1:2222"
    Write-Host ''
    Write-Host 'In another terminal, forward the app and LDAPS ports:'
    Write-Host "  ssh -N -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=`"$knownHostsFile`" -L 8100:127.0.0.1:8100 -L 1636:127.0.0.1:1636 -p 2222 -i `"$sshIdentity`" laborant@127.0.0.1"
    Write-Host ''
    Write-Host 'Open http://127.0.0.1:8100/install.php and create the first administrator.'
    Write-Host 'Configure Admin > LDAP Import with:'
    Write-Host '  Host: dc1.teste.local; port: 1636; LDAPS; certificate verification enabled'
    Write-Host '  CA file on the playground: /home/laborant/samba-ad-ca.pem'
    Write-Host '  Base DN: DC=teste,DC=local'
    Write-Host '  Bind DN: CN=svc-subsig,CN=Users,DC=teste,DC=local'
    Write-Host "  Bind password: $servicePassword"
    Write-Host ''
    Write-Host "Active test login: jit-active / $activePassword"
    Write-Host "Disabled test login: jit-disabled / $disabledPassword"
    Write-Host ''
    Write-Host "After testing, destroy the playground with: labctl playground destroy $playgroundId"
    Write-Host "Remove the temporary SSH host-key directory with: Remove-Item -Recurse -Force `"$runDirectory`""
}
catch {
    if ($playgroundId) {
        & labctl playground destroy $playgroundId --quiet 2>$null | Out-Null
    }
    if ($runDirectory -and (Test-Path $runDirectory)) {
        Remove-Item -Recurse -Force $runDirectory
    }
    throw
}
