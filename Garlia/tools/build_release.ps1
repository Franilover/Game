$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$DataDir = Join-Path $RootDir "data"
$DistDir = Join-Path $RootDir "dist"
$Snapshot = Join-Path $DataDir "world_initial.json"
$TempSnapshot = Join-Path $env:TEMP "garlia_world_initial.json"

$SupabaseUrl = "https://ftdxthnizdosaaavjhah.supabase.co"
$RpcUrl = "$SupabaseUrl/rest/v1/rpc/get_mundo_inicial"
$SupabaseKey = "sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"

function Test-Snapshot {
    param([string]$Path)

    try {
        $data = Get-Content -Raw -Path $Path | ConvertFrom-Json
    }
    catch {
        return $false
    }

    return $null -ne $data.biomas -and $data.biomas -is [System.Array]
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "== Garlia: preparando snapshot del mundo =="

try {
    $response = Invoke-WebRequest `
        -Uri $RpcUrl `
        -Method Post `
        -Headers @{ "apikey" = $SupabaseKey } `
        -ContentType "application/json" `
        -Body "{}" `
        -TimeoutSec 30

    [System.IO.File]::WriteAllText(
        $TempSnapshot,
        $response.Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Snapshot $TempSnapshot)) {
        throw "Supabase devolvió un snapshot inválido."
    }

    Copy-Item -Force $TempSnapshot $Snapshot
    Write-Host "Snapshot actualizado desde Supabase."
}
catch {
    Write-Host "No se pudo consultar Supabase durante el build."

    if (-not (Test-Path $Snapshot)) {
        throw "No existe un snapshot local para construir el juego offline."
    }

    Write-Host "Se conservará el snapshot anterior."
}
finally {
    Remove-Item -Force $TempSnapshot -ErrorAction SilentlyContinue
}

$godot = Get-Command godot -ErrorAction SilentlyContinue
if ($null -eq $godot) {
    $godot = Get-Command godot4 -ErrorAction SilentlyContinue
}

if ($null -eq $godot) {
    throw "No se encontró godot ni godot4 en PATH."
}

Remove-Item -Recurse -Force $DistDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "== Garlia: exportando Windows =="

$exePath = Join-Path $DistDir "Garlia.exe"

& $godot.Source `
    --headless `
    --path $RootDir `
    --export-release "Windows Desktop" $exePath

Write-Host ""
Write-Host "Build terminado."
Write-Host "Windows:"
Write-Host "  $exePath"
Write-Host "Snapshot:"
Write-Host "  $Snapshot"
