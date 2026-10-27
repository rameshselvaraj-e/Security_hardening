#!/bin/bash
# Email users their password expiry date when it is within WARN_DAYS.
#
# Usage:
#   ./notify_password_expiry.sh --dry-run   # preview only, nothing is sent
#   ./notify_password_expiry.sh --report    # table of ALL users and days left
#   ./notify_password_expiry.sh             # send emails (use this in cron)
#
# Requires: mail (mailutils/mailx) for real sending.

WARN_DAYS=14
MIN_UID=1000
ADMIN_MAIL="esrlabitadmin@gmail.com"   # CC for admins (empty to disable)

MODE="send"
case "$1" in
    --dry-run) MODE="dry" ;;
    --report)  MODE="report" ;;
    "")        ;;
    *) echo "Usage: $0 [--dry-run|--report]"; exit 1 ;;
esac

today=$(date +%s)

[[ $MODE == "report" ]] && printf "%-15s %-14s %-10s %s\n" USER EXPIRES DAYS_LEFT WILL_NOTIFY

getent passwd | awk -F: -v min="$MIN_UID" '$3>=min && $1!="nobody"{print $1}' | while read -r user; do
    expires=$(chage -l "$user" | awk -F': ' '/^Password expires/{print $2}')
    if [[ -z "$expires" || "$expires" == "never" ]]; then
        [[ $MODE == "report" ]] && printf "%-15s %-14s %-10s %s\n" "$user" "never" "-" "no"
        continue
    fi

    exp_epoch=$(date -d "$expires" +%s 2>/dev/null) || continue
    days_left=$(( (exp_epoch - today) / 86400 ))
    notify="no"; (( days_left <= WARN_DAYS )) && notify="yes"

    if [[ $MODE == "report" ]]; then
        printf "%-15s %-14s %-10s %s\n" "$user" "$expires" "$days_left" "$notify"
        continue
    fi
    [[ $notify == "no" ]] && continue

    if (( days_left < 0 )); then
        subject="[$(hostname)] Your password has EXPIRED"
        body="Hello $user,\n\nYour password on $(hostname) expired on $expires.\nPlease contact the administrator or change it immediately with: passwd\n"
    else
        subject="[$(hostname)] Password expires in $days_left day(s)"
        body="Hello $user,\n\nYour password on $(hostname) will expire on $expires ($days_left day(s) left).\nPlease change it now by running: passwd\n"
    fi

    if [[ $MODE == "dry" ]]; then
        echo "=============================================="
        echo "TO:      $user"
        [[ -n "$ADMIN_MAIL" ]] && echo "CC:      $ADMIN_MAIL"
        echo "SUBJECT: $subject"
        echo "----------------------------------------------"
        printf "%b" "$body"
        echo
    else
        printf "%b" "$body" | mail -s "$subject" ${ADMIN_MAIL:+"$ADMIN_MAIL"} "$user"
        logger -t pw-expiry-notify "Notified $user: expires $expires ($days_left days)"
    fi
done
