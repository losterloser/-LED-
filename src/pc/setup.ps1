param([string]$PythonPath='')
$ErrorActionPreference='Stop'
if(-not $PythonPath){$PythonPath=(Get-Command python -ErrorAction Stop).Source}
& $PythonPath -c 'import sys; assert sys.version_info[:2] == (3,12), "Use Python 3.12"'
if($LASTEXITCODE -ne 0){throw 'Python 3.12 is required for the verified environment'}
$taskVenv=Join-Path $PSScriptRoot '.venv'
if(-not (Test-Path -LiteralPath (Join-Path $taskVenv 'Scripts\python.exe'))){
    & $PythonPath -m venv $taskVenv
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
}
& (Join-Path $taskVenv 'Scripts\python.exe') -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt')
exit $LASTEXITCODE
