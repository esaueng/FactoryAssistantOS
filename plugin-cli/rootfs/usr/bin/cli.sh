#!/usr/bin/env bash
set -uo pipefail

print_banner() {
    cat <<'BANNER'
Factory Assistant CLI
Factory Assistant OS - industrial monitoring appliance
Factory Assistant is based on Home Assistant.
Monitoring only - not a safety device.
BANNER
    echo ""
}

print_banner

COMMAND=""
while true; do
    COMMAND="$(rlwrap -S $'\e[32mfa > \e[0m' -H /tmp/.cli_history -o cat)"

    if [ "$COMMAND" == "help" ]; then
        echo 'Note: Use "login" to enter operating system shell'
    elif [ "$COMMAND" == "login" ]; then
        exit 10
    elif [ "$COMMAND" == "exit" ]; then
        exit
    elif [ -z "${COMMAND##ha *}" ]; then
        echo "Note: Leading 'ha' is not necessary in this Factory Assistant CLI"
        COMMAND="${COMMAND#ha }"
    fi

    printf '%s\n' "$COMMAND" | xargs -o ha
    echo ""
done
