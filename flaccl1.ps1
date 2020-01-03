param(
    [string]$ext = 'm4a',
    [int32]$jobs,
    [switch]$h,
    [switch]$r
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
    Write-Output "Converts [$ext] files from `$pwd recursivly to flac using CUETool's Flaccl"
    Write-Output "Requires CUETools.FLACCL.cmd.exe and ffmpeg to be in env:path"
    Write-Output "flaccl can only handle 24bit and 16 bit"
    Write-Output "32bit and codecs without a bitdepth will be converted to 24bit"
    Write-Output "  -ext [$ext] for input file extension"
    Write-Output "  -jobs [$jobs] for the ammount of concurrent converts"
    exit
}

$extension = ('*.' + $ext)

if ($r) {
    $lscommands = 'Get-ChildItem -File -Recurse -filter $extension'
} else {
    $lscommands = 'Get-ChildItem -File -filter $extension'
}

Invoke-Expression $lscommands | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -ne $jobs) {
            Start-Job -ArgumentList $_, $ext -ScriptBlock {
                param($inputfile, $ext);
                if ($inputfile.Extension -ne '.wav') {
                    if ((ffprobe.exe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample -of default=noprint_wrappers=1:nokey=1 -i $inputfile) -eq "16") {
                        $bit = "16"
                    } else {
                        $bit = "24"
                    }
                    $tempfile = New-TemporaryFile
                    ffmpeg.exe -y -threads 8 -loglevel fatal -i $inputfile.FullName -c:a ('pcm_s' + $bit + 'le') -f wav $tempfile.FullName
                    Move-Item $tempfile.FullName $tempfile.FullName.Replace($tempfile.Extension, '.wav')
                    $tempi = Get-Item $tempfile.FullName.Replace($tempfile.Extension, '.wav')
                } else {
                    $tempi = Get-Item $inputfile.FullName
                }
                ffmpeg.exe -y -threads 8 -loglevel fatal -i $inputfile.FullName -map_metadata 0 -map_metadata:s:v 0:s:v -map_metadata:s:a 0:s:a -f ffmetadata $inputfile.FullName.Replace($inputfile.Extension, '.txt')
                $tempfile1 = New-TemporaryFile
                Move-Item $tempfile1.FullName $tempfile1.FullName.Replace($tempfile1.Extension, '.flac')
                CUETools.FLACCL.cmd.exe -8 --cpu-threads 8 --ignore-chunk-sizes -o $tempfile1.FullName.Replace($tempfile1.Extension, '.flac') $tempi.FullName
                ffmpeg.exe -y -threads 8 -loglevel fatal -i $tempfile1.FullName.Replace($tempfile1.Extension, '.flac') -i $inputfile.FullName.Replace($inputfile.Extension, '.txt') -map_metadata 1 -c copy $inputfile.FullName.Replace($inputfile.Extension, '.flac')
                if (ffprobe.exe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -i $inputfile) {
                    if ((ffprobe.exe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -i $inputfile) -eq "mjpeg") {
                        $type = ".jpg"
                    } else {
                        $type = ".png"
                    }
                    ffmpeg.exe -i $inputfile -an -c:v copy -sn $inputfile.FullName.Replace($inputfile.extension, $type)
                    metaflac.exe --import-picture-from $inputfile.FullName.Replace($inputfile.extension, $type) $inputfile.FullName.Replace($inputfile.Extension, '.flac')
                    Remove-Item $inputfile.FullName.Replace($inputfile.extension, $type)
                }
                if ($inputfile.Extension -ne '.wav') { Remove-Item $tempfile.FullName.Replace($tempfile.Extension, '.wav') }
                Remove-Item $inputfile.FullName.Replace($inputfile.Extension, '.txt')
                Remove-Item $tempfile1.FullName.Replace($tempfile1.Extension, '.flac')
            }
            $Check = $true
        }
    }
    Remove-Job -State Completed
}