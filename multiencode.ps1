param(
    [Parameter(Mandatory = $true)][string]$i = ".jpg",
    [Parameter(Mandatory = $true)][string]$o = ".webp",
    [int]$jobs,
    [string]$ve,
    [string]$vc,
    [string]$ae,
    [string]$ac
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

Get-Item ('*' + $i) | ForEach-Object {
    $Check = $false
    while ($Check -eq $false) {
        if ((Get-Job -State 'Running').Count -ne 8) {
            Start-Job -ArgumentList $_, $i, $o, $ve, $vc, $ae, $ac -ScriptBlock {
                param($inputfile, $informat, $outformat, $ve, $vc, $ae, $ac);
                $infile = Get-Item $inputfile
                $audioencoder = ("-c:a " + $ae)
                $videoencoder = ("-c:v " + $ve)
                if ([string]::IsNullOrEmpty($ve)) {
                    if ([string]::IsNullOrEmpty($ae)) {
                        Write-Output "w/o both"
                        ffmpeg.exe -threads 8 -y -i $infile.FullName $infile.FullName.Replace($infile.Extension, $outformat)
                    } else {
                        Write-Output "w/o video"
                        ffmpeg.exe -threads 8 -y -i $infile.FullName $audioencoder $infile.FullName.Replace($infile.Extension, $outformat)
                    }
                } else {
                    if ([string]::IsNullOrEmpty($ae)) {
                        Write-Output "w/o audio"
                        Write-Output $videoencoder
                        Write-Output $vc
                        ffmpeg.exe -threads 8 -v 100 -y -i $infile.FullName -c:v $ve -lossless:v 1 -pix_fmt bgra $infile.FullName.Replace($infile.Extension, $outformat)
                    } else {
                        Write-Output "w both"
                        ffmpeg.exe -threads 8 -y -i $infile.FullName $videoencoder $audioencoder $infile.FullName.Replace($infile.Extension, $outformat)
                    }
                }


                #                Write-Output $infile.FullName $videoencoder $audioencoder ((join-path $infile.DirectoryName  $infile.BaseName) + $outformat)
                #                ffmpeg -threads 8 -y -i $infile.FullName $videoencoder $audioencoder ((join-path $infile.DirectoryName  $infile.BaseName) + $outformat)
                #                $inputfile.FullName.Replace($inputfile.Extension,$('.' + $outf))
            }
            $Check = $true
        }
    }
    #    Remove-Job -State Completed
}
