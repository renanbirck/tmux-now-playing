#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$(dirname "$CURRENT_DIR")/scripts/cache.sh"
source "$(dirname "$CURRENT_DIR")/scripts/helpers.sh"

CIDER_HOST="$(get_tmux_option "@now-playing-cider-host" "127.0.0.1")"
CIDER_PORT="$(get_tmux_option "@now-playing-cider-port" "10767")"
CIDER_TOKEN="$(get_tmux_option "@now-playing-cider-token" "")"

parse_json() {
  printf '%s' "$1" | jq -rc "$2"
}

cider() {
  parse_json "$(curl -sSL "$CIDER_HOST:$CIDER_PORT/api/v1/playback$1")" "$2"
}

is_running() {
  if ! test -n "$(command -v curl)" -a -n "$(command -v jq)"; then
    return 1
  fi
  if test "$(cider /active .status)" != 'ok'; then
    return 1
  fi
  return 0
}

is_playing() {
  if ! is_running; then
    return 1
  fi

  _cider_status() {
    cider /now-playing '.info.currentPlaybackTime | type'
  }

  local cider_status="$(_cache_value cider_status _cider_status)"

  if test "$cider_status" != "number"; then
    return 1
  fi

  return 0
}

get_music_data() {
  _cider_state() {
    cider /is-playing '.is_playing'
  }
  local cider_state="$(_cache_value cider_state _cider_state)"
  _cider_data() {
    cider /now-playing .
  }
  local cider_data="$(_cache_value cider_data _cider_data)"

  local position="$(parse_json "$cider_data" '.info.currentPlaybackTime // 0 | floor')"
  local duration="$(parse_json "$cider_data" '(.info.durationInMillis // 0) / 1000 | floor')"
  local title="$(parse_json "$cider_data" .info.name)"
  local artist="$(parse_json "$cider_data" .info.artistName)"

  local status=""
  if test "$cider_state" = "true"; then
    status="playing"
  else
    status="paused"
  fi

  printf "%s\n%s\n%s\n%s\n%s\nCider" "$status" "$position" "$duration" "$title" "$artist"
}

send_command() {
  sh -c "(printf \"$1\nclose\n\"; sleep 0.05) | nc \"$CIDER_HOST\" \"$CIDER_PORT\"" > /dev/null
}
