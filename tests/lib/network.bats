#!/usr/bin/env bats

load '../test_helper.sh'

setup() {
    _test_helper_setup
    source "${LIMACODE_ROOT}/lib/network.sh"
}

teardown() {
    _test_helper_teardown
}

@test "network_generate_iptables_script produces valid script" {
    result="$(network_generate_iptables_script "api.anthropic.com,github.com")"
    [[ "$result" == *"#!/bin/bash"* ]]
    [[ "$result" == *"iptables"* ]]
    [[ "$result" == *"api.anthropic.com"* ]]
    [[ "$result" == *"github.com"* ]]
}

@test "network_generate_iptables_script allows loopback" {
    result="$(network_generate_iptables_script "example.com")"
    [[ "$result" == *"-o lo -j ACCEPT"* ]]
}

@test "network_generate_iptables_script allows Lima private ranges" {
    result="$(network_generate_iptables_script "example.com")"
    [[ "$result" == *"192.168.0.0/16"* ]]
    [[ "$result" == *"10.0.0.0/8"* ]]
}

@test "network_generate_iptables_script allows DNS" {
    result="$(network_generate_iptables_script "example.com")"
    [[ "$result" == *"udp --dport 53"* ]]
}

@test "network_generate_iptables_script sets DROP policy" {
    result="$(network_generate_iptables_script "example.com")"
    [[ "$result" == *"OUTPUT DROP"* ]]
}

@test "network_generate_iptables_script includes cron refresh" {
    result="$(network_generate_iptables_script "example.com")"
    [[ "$result" == *"cron"* ]]
}

@test "network_generate_iptables_script handles empty input" {
    run network_generate_iptables_script ""
    [ "$status" -ne 0 ]
}
