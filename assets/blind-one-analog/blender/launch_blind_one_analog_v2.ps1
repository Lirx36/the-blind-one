param(
    [switch]$Background,
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

$sharedLauncher = Join-Path $PSScriptRoot 'launch_blind_one_analog_v1.ps1'
$builder = Join-Path $PSScriptRoot 'build_blind_one_analog_v2.py'

& $sharedLauncher -Builder $builder -Background:$Background -Wait:$Wait
