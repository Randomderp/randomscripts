param(
    [Parameter(Mandatory = $true)][string]$i,
    [int32]$s = 300,
    [int32]$jobs,
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

$infile0 = Get-Item $i
mkdir -Force $infile0.BaseName > $null
ffmpeg.exe -threads 8 -loglevel fatal -y -i $infile0.FullName -c copy -map 0 -segment_time $s -f segment -reset_timestamps 1 ($infile0.BaseName + "/%03d" + $infile0.Extension)

Set-Location $infile0.BaseName
$Workpwd = Get-ChildItem -Directory -Filter $infile0.BaseName
Get-ChildItem -File -Filter ('*' + $infile0.Extension) | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -ne $jobs) {
            Start-Job -ArgumentList $_, $Workpwd -ScriptBlock {
                param($inputfile, $Workpwd)
                $tmpfile = New-TemporaryFile
                Set-Location $Workpwd
                ffmpeg.exe -threads 8 -y -i $inputfile.FullName -c:v libx265 -preset veryslow -c:a libopus -f matroska $tmpfile
                Move-Item -Force $tmpfile $inputfile.FullName
            }
            $Check = $true
        }
    }
    Remove-Job -State Completed
}
Get-ChildItem -Filter "*.mkv" -name | ForEach-Object { Write-Output "file '$_'" } | Out-File -Encoding utf8 cat.txt
(Get-Content cat.txt -Raw).Replace("`r`n", "`n") | Set-Content cat.txt -Force
ffmpeg.exe -threads 8 -y -f concat -safe 0 -i cat.txt -c copy ('../' + $infile0.BaseName + 'new' + $infile0.Extension)
Set-Location ..