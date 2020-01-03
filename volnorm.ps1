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

Get-ChildItem -Recurse -File -Filter "$('*.' + $inf)" | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -ne $jobs) {
            Start-Job -ArgumentList $_, $inf -ScriptBlock {
                param($inputfile, $inf);
                $tempfile = New-TemporaryFile
                $bit = ffprobe.exe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample -of default=noprint_wrappers=1:nokey=1 -i $inputfile
                $gain = (ffmpeg.exe -hide_banner -nostats -i $inputfile -af "replaygain" -f null NULL 2>&1 | grep.exe "track_gain" | cut.exe -d ' ' -f 6-) | Out-String
                ffmpeg.exe -y -hide_banner -nostats -threads 8 -i $inputfile.FullName -af "volume=$gain" -c:a ('pcm_s' + $bit + 'le') -f wav $tempfile.FullName
                ffmpeg.exe -y -hide_banner -nostats -threads 8 -i $tempfile.FullName -c:a flac $inputfile.FullName.Replace($inputfile.Extension, '.flac')
                Remove-Item $tempfile.FullName
            }
            $Check = $true
        }
    }
    #    Remove-Job -State Completed
}
#-filter_complex "[0:a]volume=$gain[1:a];[1:a]volume=+6dB[outa]" -map "[outa]"