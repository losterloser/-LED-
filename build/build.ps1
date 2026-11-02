param(
    [ValidateSet('create','all','simulate','synth','implement','bitstream')][string]$Mode='all',
    [string]$VivadoExe='',
    [ValidatePattern('^[A-Z]$')][string]$Drive='R'
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
if(-not $VivadoExe){
    if($env:VIVADO_EXE){$VivadoExe=$env:VIVADO_EXE}
    else {$VivadoExe=(Get-Command vivado.bat -ErrorAction Stop).Source}
}
if(-not (Test-Path -LiteralPath $VivadoExe)){throw 'Pass -VivadoExe with the full Vivado 2022.2 path'}
$taskDriveName=$Drive+':'
$taskDriveRoot=$taskDriveName+'\'
if(Test-Path -LiteralPath $taskDriveRoot){throw "Drive $taskDriveName is in use; choose another -Drive"}
New-Item -ItemType Directory -Force -Path (Join-Path $taskRoot 'build\current'),(Join-Path $taskRoot 'board\output') | Out-Null
$taskStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
& subst $taskDriveName $taskRoot
if($LASTEXITCODE -ne 0){throw 'Could not create temporary short path'}
$taskCode=1
try {
    Push-Location -LiteralPath $taskDriveRoot
    try {
        if($Mode -eq 'create'){
            & $VivadoExe -mode batch -notrace -log "build/current/create_$taskStamp.log" -journal "build/current/create_$taskStamp.jou" -source build/create_project.tcl
        } else {
            & $VivadoExe -mode batch -notrace -log "build/current/build_${Mode}_$taskStamp.log" -journal "build/current/build_${Mode}_$taskStamp.jou" -source build/run_checks.tcl -tclargs $Mode
        }
        $taskCode=$LASTEXITCODE
        if($taskCode -eq 0 -and $Mode -in @('all','implement','bitstream')){
            & $VivadoExe -mode batch -notrace -log build/current/post_checkpoint_signoff.log -journal build/current/post_checkpoint_signoff.jou -source build/post_checkpoint_signoff.tcl
            $taskCode=$LASTEXITCODE
        }
    } finally {Pop-Location}
} finally {
    $taskMapping=@(& subst) | Where-Object {$_ -like ($Drive+':*')}
    if($taskMapping -and ($taskMapping -join ' ').IndexOf($taskRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0){& subst $taskDriveName /D}
}
exit $taskCode
