param(
    [int32]$jobs,
    [string]$path = $PWD,
    [switch]$h
)

if ($jobs -eq 0) {
    if ($IsWindows) {
        $jobs = (Get-CimInstance -ClassName 'Win32_ComputerSystem').NumberOfLogicalProcessors
    } elseif ($IsMacOS) {
        $jobs = sysctl -n hw.ncpu
    } else {
        $jobs = grep.exe -c ^processor /proc/cpuinfo
    }
}

if ($h) {
    Write-Output "Tars folders in `$path"
    Write-Output "Must have 7z in env:path"
    Write-Output "Slightly tested on *nix"
    Write-Output "  -jobs [$jobs] for the ammount of concurrent converts"
    Write-Output "  -path [$path] where 7z will look from and output to"
    exit
}
if (-Not (Test-Path -Path $path)) {
    Exit
}
Get-ChildItem -Directory $path | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -lt $jobs) {
            Start-Job  -ArgumentList $_, $path -ScriptBlock {
                param($folder, $path)
                $folder = Get-Item $folder
                7z.exe a $path/$($folder.basename).tar $($folder.FullName + '/*')
            }
            $Check = $true
        }
    }
    Remove-Job -State Completed
}