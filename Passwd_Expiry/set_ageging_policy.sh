#!/bin/bash
# Re-apply the password aging policy to all regular users.
# Run as root, monthly from cron.

MIN_DAYS=7        # -m  minimum days between changes
MAX_DAYS=30       # -M  maximum days between changes
WARN_DAYS=14      # -W  warning days before expiry
INACTIVE_DAYS=5   # -I  days after expiry before account is locked
MIN_UID=1000
EXCLUDE="nobody"  # space-separated users to skip (e.g. service/admin accounts)
# Optional: push account expiry out each run (e.g. 6 months). Leave empty to skip.
ACCOUNT_EXPIRE_MONTHS=""

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

getent passwd | awk -F: -v min="$MIN_UID" '$3>=min{print $1}' | while read -r user; do
    [[ " $EXCLUDE " == *" $user "* ]] && continue

    chage -m "$MIN_DAYS" -M "$MAX_DAYS" -W "$WARN_DAYS" -I "$INACTIVE_DAYS" "$user"

    if [[ -n "$ACCOUNT_EXPIRE_MONTHS" ]]; then
        chage -E "$(date -d "+${ACCOUNT_EXPIRE_MONTHS} months" +%F)" "$user"
    fi

    logger -t pw-aging "Applied aging policy to $user"
    echo "Updated: $user"
done
