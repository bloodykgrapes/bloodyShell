/^[[:space:]]*-?auth[[:space:]].*[[:space:]]pam_gnome_keyring\.so([[:space:]]|$)/ { auth = 1 }
/^[[:space:]]*-?session[[:space:]].*[[:space:]]pam_gnome_keyring\.so([[:space:]]|$)/ {
    session = 1
    if ($0 !~ /(^|[[:space:]])auto_start([[:space:]]|$)/) {
        sub(/[[:space:]]*#/, " auto_start #")
        if ($0 !~ /(^|[[:space:]])auto_start([[:space:]]|$)/) $0 = $0 " auto_start"
    }
}
{ print }
END {
    if (!auth) print "-auth      optional     pam_gnome_keyring.so"
    if (!session) print "-session   optional     pam_gnome_keyring.so auto_start"
}
