#!/bin/bash

###############################################################################
# postfix_zabbix.sh
#
# Author:
#   John Stray
#
# License:
#   MIT
#
# Copyright:
#   Copyright (c) 2026 John Stray
#
# Purpose:
#   Collect Postfix SMTP operational metrics for Zabbix agent UserParameter
#   checks and return a single value for the requested metric key.
#
# How it works:
#   - Reads recent mail log entries (tail of /var/log/mail.log)
#   - Computes counters and service checks
#   - Stores results in a short-lived JSON cache file
#   - Returns one metric value selected by the first script argument
#
# Usage:
#   postfix_zabbix.sh <metric_key>
#
# Examples:
#   postfix_zabbix.sh pfmailq
#   postfix_zabbix.sh errors
#   postfix_zabbix.sh smtp_check
#   postfix_zabbix.sh cert_days_587
#
# Cache:
#   File: /var/tmp/postfix_log_analysis.cache
#   TTL : 60 seconds
#
# Dependencies:
#   bash, tail, grep, awk, sed, sort, wc, timeout, openssl, postqueue, bc
#   Optional: jq (preferred for JSON output parsing)
###############################################################################

DOMAIN=$(hostname -f)
CACHE_FILE="/var/tmp/postfix_log_analysis.cache"
CACHE_MAX_AGE=60  # 60 Second Cache

# Safe Count Function (robust against errors)
safe_count() {
    local pattern="$1"
    local count=$(echo "$LOGS" | grep -c "$pattern" 2>/dev/null)
    count=$(echo "$count" | head -1)
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        count=0
    fi
    echo "$count"
}

cert_days() {
    if [ "$1" -eq 587 ]; then
        EXPIRY=$(openssl s_client -connect $DOMAIN:587 -starttls smtp -servername $DOMAIN </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    else
        EXPIRY=$(openssl s_client -connect $DOMAIN:$1 -servername $DOMAIN </dev/null 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    fi
    if [ -n "$EXPIRY" ]; then
        EXPIRY_DATE=$(date -d "$EXPIRY" +%s)
        CURRENT_DATE=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_DATE - CURRENT_DATE) / 86400 ))
        echo "$DAYS_LEFT"
    else
        echo "0"
    fi
}

cert_raw() {
    if [ "$1" = "587" ]; then
        CERTDATA=$(echo | timeout 5 openssl s_client -connect "$DOMAIN:587" -starttls smtp -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -enddate -subject 2>/dev/null || echo "none")
        CERT_RAW=$(echo "$CERTDATA" | tr '\n' ' ' | xargs)
    else
        CERTDATA=$(echo | timeout 5 openssl s_client -connect "$DOMAIN:$1" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -enddate -subject 2>/dev/null || echo "none")
        CERT_RAW=$(echo "$CERTDATA" | tr '\n' ' ' | xargs)
    fi
    echo "$CERT_RAW"
}

# Cache aktualisieren wenn nötig
update_cache() {
    LOGS=$(sudo journalctl -u postfix --no-pager 2>/dev/null)

    # Alle Counts in einem Durchgang
    SASL_AUTH_FAILED=$(echo "$LOGS" | grep -c "SASL.*authentication failed")
    RELAY_DENIED=$(echo "$LOGS" | grep -c "Relay access denied")
    USER_UNKNOWN=$(echo "$LOGS" | grep -c "User unknown in")
    RBL_REJECT=$(echo "$LOGS" | grep -c "blocked using")
    CONNECTION_TIMEOUT=$(echo "$LOGS" | grep -c "Connection timed out")
    TLS_FAILED=$(echo "$LOGS" | grep -cE "TLS.*handshake failed|SSL.*error")
    QUOTA_EXCEEDED=$(echo "$LOGS" | grep -cE "mailbox.*full|quota.*exceeded|Disk quota")
    SPAM_REJECTED=$(echo "$LOGS" | grep -c "milter-reject.*Spam message rejected")
    VIRUS_FOUND=$(echo "$LOGS" | grep -c "Infected.*FOUND")
    WARNINGS=$(echo "$LOGS" | grep -c "warning:")
    ERRORS=$(echo "$LOGS" | grep -cE "error:|fatal:")
    # Postscreen Stats (nur wenn aktiv)
    POSTSCREEN_PASS_NEW=$(echo "$LOGS" | grep -c "postscreen.*PASS NEW")
    POSTSCREEN_PASS_OLD=$(echo "$LOGS" | grep -c "postscreen.*PASS OLD")
    POSTSCREEN_REJECT=$(echo "$LOGS" | grep -c "postscreen.*NOQUEUE.*reject")
    POSTSCREEN_DNSBL=$(echo "$LOGS" | grep -c "postscreen.*DNSBL")
    POSTSCREEN_PREGREET=$(echo "$LOGS" | grep -c "postscreen.*PREGREET")
    POSTSCREEN_HANGUP=$(echo "$LOGS" | grep -c "postscreen.*HANGUP")
    POSTSCREEN_WHITELISTED=$(echo "$LOGS" | grep -c "postscreen.*WHITELISTED")
    POSTSCREEN_CONNECT=$(echo "$LOGS" | grep -c "postscreen.*CONNECT")
    # Aktiv = mindestens 1 postscreen-Logeintrag
    if ((POSTSCREEN_CONNECT > 0 || POSTSCREEN_PASS_NEW > 0)); then
        POSTSCREEN_ACTIVE=1
    else
        POSTSCREEN_ACTIVE=0
    fi

    # Metric counts
    RECEIVED=$(safe_count "postfix/smtpd.*client=")
    DELIVERED=$(safe_count "status=sent")
    BOUNCED=$(safe_count "status=bounced")
    DEFERRED=$(safe_count "status=deferred")
    REJECTED=$(safe_count "reject:")
    REJECT_WARN=$(safe_count "reject_warning")
    DISCARDED=$(safe_count "discard:")
    HELD=$(safe_count "status=hold")
    FORWARDED=$(safe_count "forwarded")
    BYTES_RECEIVED=$(echo -e "$LOGS" | grep -m 1 "bytes received" | cut -f1 -d"b"|sed -e 's/k/\*1024/g' -e 's/m/\*1048576/g' -e 's/g/\*1073741824/g' |bc)
    BYTES_DELIVERED=$(echo -e "$LOGS" | grep -m 1 "bytes delivered" | cut -f1 -d"b"|sed -e 's/k/\*1024/g' -e 's/m/\*1048576/g' -e 's/g/\*1073741824/g' |bc)

    # Senders & Recipients
    SENDERS=$(echo "$LOGS" | grep "from=<" 2>/dev/null | grep -oP 'from=<[^>]+>' 2>/dev/null | sort -u | wc -l | head -1)
    RECIPIENTS=$(echo "$LOGS" | grep "to=<" 2>/dev/null | grep -oP 'to=<[^>]+>' 2>/dev/null | sort -u | wc -l | head -1)

    [[ "$SENDERS" =~ ^[0-9]+$ ]] || SENDERS=0
    [[ "$RECIPIENTS" =~ ^[0-9]+$ ]] || RECIPIENTS=0

    CHECK_PORT_465=$(timeout 3 bash -c "</dev/tcp/$DOMAIN/465" &>/dev/null && echo 1 || echo 0)
    CHECK_PORT_587=$(timeout 3 bash -c "</dev/tcp/$DOMAIN/587" &>/dev/null && echo 1 || echo 0)
    CHECK_PORT_25=$(timeout 3 bash -c "</dev/tcp/$DOMAIN/25" &>/dev/null && echo 1 || echo 0)

    MAILQUEUE=$(postqueue -p 2>/dev/null | tail -n1)
    if [[ "$MAILQUEUE" == "Mail queue is empty" ]]; then
        QUEUE_SIZE=0
    else
        QUEUE_SIZE=$(echo "$MAILQUEUE" | awk '{print $5}' 2>/dev/null | head -1)
        [[ "$QUEUE_SIZE" =~ ^[0-9]+$ ]] || QUEUE_SIZE=0
    fi

    # JSON schreiben
    cat > "$CACHE_FILE" << EOFJSON
{
  "pfmailq": $QUEUE_SIZE,
  "sasl_auth_failed": $SASL_AUTH_FAILED,
  "relay_denied": $RELAY_DENIED,
  "user_unknown": $USER_UNKNOWN,
  "rbl_reject": $RBL_REJECT,
  "connection_timeout": $CONNECTION_TIMEOUT,
  "tls_failed": $TLS_FAILED,
  "quota_exceeded": $QUOTA_EXCEEDED,
  "spam_rejected": $SPAM_REJECTED,
  "virus_found": $VIRUS_FOUND,
  "warnings": $WARNINGS,
  "errors": $ERRORS,
  "postscreen_active": $POSTSCREEN_ACTIVE,
  "postscreen_pass_new": $POSTSCREEN_PASS_NEW,
  "postscreen_pass_old": $POSTSCREEN_PASS_OLD,
  "postscreen_reject": $POSTSCREEN_REJECT,
  "postscreen_dnsbl": $POSTSCREEN_DNSBL,
  "postscreen_pregreet": $POSTSCREEN_PREGREET,
  "postscreen_hangup": $POSTSCREEN_HANGUP,
  "postscreen_whitelisted": $POSTSCREEN_WHITELISTED,
  "postscreen_connect": $POSTSCREEN_CONNECT,
  "received": $RECEIVED,
  "delivered": $DELIVERED,
  "bounced": $BOUNCED,
  "deferred": $DEFERRED,
  "rejected": $REJECTED,
  "reject_warnings": $REJECT_WARN,
  "discarded": $DISCARDED,
  "held": $HELD,
  "forwarded": $FORWARDED,
  "bytes_received": $BYTES_RECEIVED,
  "bytes_delivered": $BYTES_DELIVERED,
  "senders": $SENDERS,
  "recipients": $RECIPIENTS,
  "bounced_domains": [],
  "submissions_check": $CHECK_PORT_465,
  "submission_check": $CHECK_PORT_587,
  "smtp_check": $CHECK_PORT_25,
  "cert_raw_465": "$(cert_raw 465)",
  "cert_raw_587": "$(cert_raw 587)",
  "cert_days_465": $(cert_days 465),
  "cert_days_587": $(cert_days 587)
}
EOFJSON
}

# Cache prüfen
if [ ! -f "$CACHE_FILE" ] || [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]; then
    update_cache
fi

# Aus Cache lesen
if command -v jq &>/dev/null; then
    cat "$CACHE_FILE" 2>/dev/null | jq -r ".${1} // 0" 2>/dev/null || echo 0
else
    grep -oP "\"$1\":\s*\K\d+" "$CACHE_FILE" 2>/dev/null || echo 0
fi
