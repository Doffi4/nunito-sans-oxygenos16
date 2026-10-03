BEGIN {
    while ((getline line < replacement_file) > 0) replacement = replacement line "\n"
    close(replacement_file)
}

!inside && /<family[[:space:]>]/ && /name="sans-serif"/ {
    seen++
    if (seen == 1) print replacement
    inside = 1
    if (index($0, "</family>")) inside = 0
    next
}

inside {
    if (index($0, "</family>")) inside = 0
    next
}

{ print }

END {
    if (inside || seen != 1) exit 2
}
