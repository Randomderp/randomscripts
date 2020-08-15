#!/bin/sh

get_loudnorm() (
    [ -f "$1" ] || return 1
    ffmpeg -threads "$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu) + 2))" \
        -hide_banner -nostats -y \
        -i "$1" -vn \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" \
        -f null - 2>&1
)

parse_loudnorm() (
    for _var in $(
        get_loudnorm "$1" |
            awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /input_i/{ print p $0 RT }' |
            jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]"
    ); do
        eval "$_var"
    done
    printf "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I='%f':measured_TP='%f':measured_LRA='%f':measured_thresh='%f':offset='%f':linear=true:print_format=summary\n" \
        "${input_i:-0.00}" \
        "${input_tp:-0.00}" \
        "${input_lra:-0.00}" \
        "${input_thresh:-0.00}" \
        "${target_offset:-0.00}"
)

run_loudnorm() (
    [ -f "$1" ] || return 1
    mkdir -p loudnorm
    outfile=$(basename "${1%.*}")
    ffmpeg -threads "$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu) + 2))" -hide_banner -nostats -y -i "$1" -c:v copy -af "$(parse_loudnorm "$1")" -compression_level 12 "loudnorm/$outfile.flac"
)

type ffmpeg jq > /dev/null 2>&1 || {
    printf 'Failed to find ffmpeg or jq, exiting early\n' >&2
    exit 1
}

for file; do
    printf 'Processing %s\n' "$file"
    run_loudnorm "$file" || exit 1
done
