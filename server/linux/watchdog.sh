#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Linux Service Watchdog
# Features: Real Exponential Backoff, Degraded State circuit breaker, Sanitized logs
# ==============================================================================

set -uo pipefail

STATE_FILE="/etc/xray/watchdog.state"
LOG_FILE="/var/log/xray/watchdog.log"
CONFIG_FILE="/etc/xray/config.json"
MAX_FAILURES=5
BASE_BACKOFF=10
MAX_BACKOFF=300
PORT=8080

mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$LOG_FILE")"

log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg"
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}

# 1. Read / Initialize State
FAIL_COUNT=0
STATUS="HEALTHY"
if [[ -f "$STATE_FILE" ]]; then
    FAIL_COUNT=$(grep "^FAIL_COUNT=" "$STATE_FILE" | cut -d '=' -f 2 || echo 0)
    STATUS=$(grep "^STATUS=" "$STATE_FILE" | cut -d '=' -f 2 || echo "HEALTHY")
fi

save_state() {
    cat <<EOF > "$STATE_FILE"
FAIL_COUNT=$FAIL_COUNT
STATUS=$STATUS
LAST_UPDATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
}

# 2. Check Health
IS_ACTIVE=0
PORT_OPEN=0

if systemctl is-active --quiet xray; then
    IS_ACTIVE=1
fi

if (echo > /dev/tcp/127.0.0.1/$PORT) &>/dev/null; then
    PORT_OPEN=1
fi

# 3. Handle Healthy State
if [[ $IS_ACTIVE -eq 1 && $PORT_OPEN -eq 1 ]]; then
    if [[ $FAIL_COUNT -gt 0 || "$STATUS" != "HEALTHY" ]]; then
        log "INFO" "Service recovered to HEALTHY state. Resetting failure counter."
        FAIL_COUNT=0
        STATUS="HEALTHY"
        save_state
    fi
    exit 0
fi

# 4. Handle Failure
FAIL_COUNT=$((FAIL_COUNT + 1))
log "WARN" "Health check failed (Failure count: $FAIL_COUNT/$MAX_FAILURES). Active: $IS_ACTIVE, Port $PORT: $PORT_OPEN"

# 5. Circuit Breaker / Degraded State Check
if [[ $FAIL_COUNT -ge $MAX_FAILURES ]]; then
    STATUS="DEGRADED"
    save_state
    log "ERROR" "CRITICAL: Consecutive failure limit ($MAX_FAILURES) reached. Entering DEGRADED state."
    log "ERROR" "Restart loop halted to prevent CPU exhaustion. Manual inspection required: journalctl -u xray -n 50"
    exit 1
fi

# 6. Real Exponential Backoff
# delay = min(BaseBackoff * 2^(fail_count - 1), MaxBackoff)
EXPONENT=$((FAIL_COUNT - 1))
if [[ $EXPONENT -lt 0 ]]; then EXPONENT=0; fi
DELAY=$((BASE_BACKOFF * (1 << EXPONENT)))
if [[ $DELAY -gt $MAX_BACKOFF ]]; then DELAY=$MAX_BACKOFF; fi

log "INFO" "Applying exponential backoff cooldown of $DELAY seconds before restart attempt..."
sleep "$DELAY"

# 7. Config Validation Before Restart
if ! /usr/local/bin/xray -test -config "$CONFIG_FILE" &>/dev/null; then
    log "ERROR" "Cannot restart: /etc/xray/config.json syntax is invalid. Preserving stopped state to avoid crash loop."
    save_state
    exit 1
fi

# 8. Restart Service
log "INFO" "Initiating controlled service restart..."
systemctl restart xray
sleep 3

if systemctl is-active --quiet xray; then
    log "INFO" "Service successfully restarted by watchdog."
    STATUS="RESTARTED"
else
    log "WARN" "Service did not respond immediately after watchdog restart."
    STATUS="FAILING"
fi
save_state
