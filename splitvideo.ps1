param(
    [Parameter(Mandatory = $true)][string]$i,
    [int32]$s = 300
)

$infile = Get-Item $i
mkdir $infile.BaseName 2>1 | Out-Null
ffmpeg.exe -threads 8 -loglevel fatal -i $infile.FullName -c copy -map 0 -segment_time $s -f segment -reset_timestamps 1 ($infile.BaseName + "/%03d" + $infile.Extension)