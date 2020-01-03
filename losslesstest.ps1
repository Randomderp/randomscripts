param(
    [string]$i,
    $encoders = ("ffv1", "libx264", "libx265", "libvpx-vp9", "libaom-av1", "nvenc_hevc", "nvenc")
)
$i = Get-Item $i
foreach ($b in $encoders) {
    $argument = switch ($b) {
        ffv1 { '-context 1' }
        libx264 { '-preset placebo -qp 0' }
        libx265 { '-preset placebo -x265-params lossless=1' }
        libvpx-vp9 { '-lossless:v 1 -deadline:v best -cpu-used:v 0 -b:v 0 -crf 0' }
        libaom-av1 { '-strict experimental -crf 0 -b:v 0' }
        nvenc* { '-preset:v lossless' }
        Default { '-lossless:v 1' }
    }
    Measure-Command -Expression { Invoke-Expression "ffmpeg -y -threads 8 -hide_banner -i $i -c:v $b $argument -c:a copy -sn $($b).mkv 2>&1 | Out-File $($b + '.txt')"
    }
}
