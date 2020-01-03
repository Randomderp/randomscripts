param(
    [string]$i = 'm4a',
    [string]$o = 'flac',
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

if ($h) {
    Write-Output "Normalizes audio using ebu128"
    Write-Output "Requires ffmpeg to be in env:path"
    Write-Output "Resamples audio to 48k"
    Write-Output "  -i [$i] for input file extension"
    Write-Output "  -o [$o] for output file extension"
    Write-Output "  -jobs [$jobs] for the ammount of concurrent converts"
    exit
}

Get-ChildItem -Recurse -Filter "$('*.' + $i)" | ForEach-Object {
    $path = $_.FullName
    $txt = $_.FullName.Replace($_.Extension, '.txt')
    $outfile = $_.FullName.Replace($_.Extension, "$('.' + $o)")
    Get-Variable _
    ffmpeg.exe -hide_banner -nostats -i $path -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | grep.exe "input\|target" | Out-File -Encoding UTF8 "$txt"
    $input_i = Get-Content "$txt" | grep.exe "input_i" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
    $input_tp = Get-Content "$txt" | grep.exe "input_tp" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
    $input_lra = Get-Content "$txt" | grep.exe "input_lra" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
    $input_thresh = Get-Content "$txt" | grep.exe "input_thresh" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
    $target_offset = Get-Content "$txt" | grep.exe "target_offset" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
    ffmpeg.exe -hide_banner -nostats -y -i $path -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I='$input_i':measured_TP='$input_tp':measured_LRA='$input_lra':measured_thresh='$input_thresh':offset='$target_offset':linear=true:print_format=summary" -ar 48k $outfile
    Remove-Item "$txt"
}