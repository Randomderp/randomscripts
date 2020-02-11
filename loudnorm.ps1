#!/usr/bin/powershell
[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        Position = 0,
        HelpMessage = "Enter a file path."
    )][Alias("i", "in")][string]$InputFile,
    [Parameter(
        Position = 1
    )][Alias("o", "out")][string]$OutputFile = $InputFile.FullName.Replace($InputFile.Extension, ".flac"),
    [switch]$Help = $false,
    [hashtable]$FFmpegCustomOpts
)
begin {
    if ($h) {
        "Normalizes audio using ebu128"
        "Requires ffmpeg to be in env:path"
        "  -InputFile [$InputFile] for input file"
        "  -OutputFile [$OutputFile] for output file"
        exit
    }
}
Process {
    $DefaultFFmpegBeginOpts = @{
        hide_banner = $null
        nostats     = $null
        y           = $null
        i           = $path
    }
    Get-Item "$InputFile" | ForEach-Object {
        $path = $_.FullName
        $txt = $_.FullName.Replace($_.Extension, '.txt')
        Write-Output "Currently processing $_"
        ffmpeg @DefaultFFmpegBeginOpts -vn -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 |
            Out-File -Encoding UTF8 "$txt"
        $input_json = Get-Content -Tail 12 "$txt" | ConvertFrom-Json
        [double]$input_i = $input_json.input_i
        [double]$input_tp = $input_json.input_tp
        [double]$input_lra = $input_json.input_lra
        [double]$input_thresh = $input_json.input_thresh
        [double]$target_offset = $input_json.target_offset
        ffmpeg @DefaultFFmpegBeginOpts -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I='$input_i':measured_TP='$input_tp':measured_LRA='$input_lra':measured_thresh='$input_thresh':offset='$target_offset':linear=true:print_format=summary" @FFmpegCustomOpts "$OutputFile"
    }
}
end {
    Remove-Item "$txt"
}
