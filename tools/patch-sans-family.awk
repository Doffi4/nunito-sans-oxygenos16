# Conservative XML subset scanner. Preserve every byte outside a unique
# top-level <family name="sans-serif"> content range; skip commented examples.
BEGIN {
    RS = "\034"
    if ((getline replacement < replacement_file) <= 0) invalid = 1
    close(replacement_file)
}

{ document = $0 }

function attribute(tag, key,    rest, attr_name, quote, offset, value, result, found) {
    rest = tag
    sub(/^<[A-Za-z_][A-Za-z0-9_.:-]*/, "", rest)
    while (length(rest)) {
        sub(/^[[:space:]]*/, "", rest)
        if (rest == ">" || rest ~ /^\/[[:space:]]*>$/) break
        if (!match(rest, /^[A-Za-z_][A-Za-z0-9_.:-]*/)) { invalid = 1; break }
        attr_name = substr(rest, 1, RLENGTH)
        rest = substr(rest, RLENGTH + 1)
        sub(/^[[:space:]]*/, "", rest)
        if (substr(rest, 1, 1) != "=") { invalid = 1; break }
        rest = substr(rest, 2)
        sub(/^[[:space:]]*/, "", rest)
        quote = substr(rest, 1, 1)
        if (quote != "\"" && quote != "'") { invalid = 1; break }
        offset = index(substr(rest, 2), quote)
        if (!offset) { invalid = 1; break }
        value = substr(rest, 2, offset - 1)
        rest = substr(rest, offset + 2)
        if (attr_name == key) {
            if (++found != 1) { invalid = 1; break }
            result = value
        }
    }
    attribute_found = found
    return result
}

function tag_end(text, start,    i, ch, quote) {
    for (i = start + 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (quote != "") {
            if (ch == quote) quote = ""
        } else if (ch == "\"" || ch == "'") quote = ch
        else if (ch == ">") return i
        else if (ch == "<") return 0
    }
    return 0
}

END {
    if (invalid || NR != 1) exit 2
    pos = 1
    while (pos <= length(document)) {
        offset = index(substr(document, pos), "<")
        if (!offset) {
            if (depth || substr(document, pos) !~ /^[[:space:]]*$/) exit 2
            break
        }
        opening = pos + offset - 1
        if (!depth && substr(document, pos, opening - pos) !~ /^[[:space:]]*$/) exit 2
        if (substr(document, opening, 4) == "<!--") {
            offset = index(substr(document, opening + 4), "-->")
            if (!offset) exit 2
            pos = opening + 4 + offset + 2
            continue
        }
        ending = tag_end(document, opening)
        if (!ending) exit 2
        tag = substr(document, opening, ending - opening + 1)
        pos = ending + 1
        if (tag ~ /^<\?xml[[:space:]]/ && tag ~ /\?>$/ && !roots) continue
        if (tag ~ /^<!/ || tag ~ /^<\?/) exit 2
        if (tag ~ /^<\//) {
            if (tag !~ /^<\/[A-Za-z_][A-Za-z0-9_.:-]*[[:space:]]*>$/) exit 2
            name = tag
            sub(/^<\//, "", name)
            sub(/[[:space:]]*>$/, "", name)
            if (!depth || stack[depth] != name) exit 2
            if (target && depth == 2) {
                content_end = opening
                target = 0
            }
            delete stack[depth]
            depth--
            continue
        }
        if (tag !~ /^<[A-Za-z_][A-Za-z0-9_.:-]*([[:space:]\/]|>)/) exit 2
        name = tag
        sub(/^</, "", name)
        sub(/[[:space:]\/>].*$/, "", name)
        self_closing = tag ~ /\/[[:space:]]*>$/
        if (!depth) {
            if (++roots != 1 || self_closing) exit 2
            root = name
            if (root != "familyset" && root != "fonts-modification") exit 2
        }
        if (depth == 1 && attribute(tag, "name") == "sans-serif") {
            if (++seen != 1 || name != "family" || self_closing) exit 2
            if (root == "fonts-modification" && attribute(tag, "customizationType") != "new-named-family") exit 2
            attribute(tag, "lang")
            if (attribute_found) exit 2
            attribute(tag, "variant")
            if (attribute_found) exit 2
            attribute(tag, "ignore")
            if (attribute_found) exit 2
            content_start = ending + 1
            target = 1
        } else if (target && (name == "family" || name == "family-list" || attribute(tag, "fallbackFor") != "")) exit 2
        if (!self_closing) stack[++depth] = name
    }
    if (invalid || depth || seen != 1 || !content_end || roots != 1) exit 2
    printf "%s%s%s", substr(document, 1, content_start - 1), replacement, substr(document, content_end)
}
