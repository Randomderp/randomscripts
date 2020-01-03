param(
    [string]$inf = 'm4a',
    [string]$outf = 'flac',
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

Get-ChildItem -Recurse -Filter "$('*.' + $inf)" | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -ne $jobs) {
            Start-Job -ArgumentList $_, $outf, $inf -ScriptBlock {
                param($inputfile, $outf, $inf);
                $txt = New-TemporaryFile
                ffmpeg.exe -hide_banner -nostats -i $inputfile.FullName -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | grep.exe "input\|target" | Out-File -Encoding UTF8 $txt
                $input_i = Get-Content $txt | grep.exe "input_i" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
                $input_tp = Get-Content $txt | grep.exe "input_tp" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
                $input_lra = Get-Content $txt | grep.exe "input_lra" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
                $input_thresh = Get-Content $txt | grep.exe "input_thresh" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
                $target_offset = Get-Content $txt | grep.exe "target_offset" | grep.exe -Eo -- "[-+]?[0-9]+\.[0-9]+"
                ffmpeg.exe -hide_banner -nostats -y -i $inputfile.FullName -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I='$input_i':measured_TP='$input_tp':measured_LRA='$input_lra':measured_thresh='$input_thresh':offset='$target_offset':linear=true:print_format=summary" -ar 48k $inputfile.FullName.Replace($inputfile.Extension, $('.' + $outf))
                Remove-Item $txt
            }
            $Check = $true
        }
    }
    Remove-Job -State Completed
}
