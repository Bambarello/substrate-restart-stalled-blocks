#!/bin/bash

######### usage one-liner
# curl -s https://raw.githubusercontent.com/Bambarello/substrate-restart-stalled-blocks/master/substrate-main-monitor.sh | bash -s -- --port {{Prometheus_PORT}} --service {{service_name}}

############ VARS

prometheus_port=9635 #### default installation is 9615
prometheus_host="127.0.0.1"
service_name="centrifuge"
metric_height='substrate_block_height'
log_time_zone="UTC"

############ PARAMETERS

while [[ $# > 0 ]]; do
	case "$1" in
		--port)
			shift 1
			prometheus_port=$1
			shift 1
		;;
		--service)
			shift 1
			service_name=$1
			shift 1
		;;
		*)
			log_exit "Unknown argument: $1"
		;;
	esac
done

############ FUNCTIONS

function log() {
        echo $(TZ=$log_time_zone date "+%Y-%m-%d %H:%M:%S") "${1}"
}

####https://stackoverflow.com/a/3951175
#### check string IS a number
function check_number() {
        _string_to_check=$1
        case $_string_to_check in
                ''|*[!0-9]*) echo "error" ;;
                *) echo "OK" ;;
        esac
}

function restart_daemon() {
        log "systemctl docker restart $service_name"
        sudo systemctl docker restart $service_name
}

function get_metrics() {
        curl -s "${prometheus_host}:${prometheus_port}/metrics"
}

####function get_peers() {
####    local _peers=$(get_metrics | awk '/^'${metric_peers}'/{print $2}')
####    case $(check_number "$_peers") in
####            "error") echo "error" ;;
####            *) echo $_peers
####    esac
####}

function get_best_block() {
        local _best_block=$(get_metrics | grep "^${metric_height}" | awk '/best/ {print $2}')
        case $(check_number "$_best_block") in
                "error") echo "error" ;;
                *) echo $_best_block
        esac
}

function alert_telegram() {
        log "TODO: alert telegram"
        #TODO: alert telegram!
}


############ MAIN

old_block=$(get_best_block)

case $old_block in
        "error")
                log "number_error after getting block! exit..."
                exit
        ;;
esac

consecutive_fails=0

log "block=$old_block"

while :; do

        sleep 1m

        if (( consecutive_fails >= 5 )); then
                log "5 consecutive fails! will restart daemon!"
                restart_daemon
                log "sleep 2m to let it connect to network..."
                sleep 2m
        fi

        new_block=$(get_best_block)
        
        case $new_block in
                "error")
                        log "number_error after getting block!"
                        consecutive_fails=$(( consecutive_fails + 1 ))
                        continue        ### do not check if error getting block
                ;;
        esac

        log "block old=$old_block, new=$new_block OK"

        if (( new_block > old_block )); then
                old_block=$new_block
                consecutive_fails=0
        else
                log "oops block not increasing!"
                consecutive_fails=$(( consecutive_fails + 1 ))
                log "consecutive_fails=$consecutive_fails"
        fi
done
