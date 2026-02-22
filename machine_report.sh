#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Global variables
MIN_NAME_LEN=5
MAX_NAME_LEN=13

MIN_DATA_LEN=20
MAX_DATA_LEN=32

BORDERS_AND_PADDING=7

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"
machine_report_high_fidelity="${MACHINE_REPORT_HIGH_FIDELITY:-0}"
machine_report_high_fidelity_interval_ms="${MACHINE_REPORT_HIGH_FIDELITY_INTERVAL_MS:-200}"
last_login_ip_present=0
zfs_present=0
zfs_filesystem="zroot/ROOT/os"
gpu_model="-"
gpu_cores="-"
gpu_api="-"
gpu_memory="-"
gpu_freq="-"
gpu_util="-"
gpu_util_pct=""
gpu_load_bar="-"

# Utilities
max_length() {
    local max_len=0
    local len

    for str in "$@"; do
        len=${#str}
        if (( len > max_len )); then
            max_len=$len
        fi
    done

    if [ $max_len -lt $MAX_DATA_LEN ]; then
        printf '%s' "$max_len"
    else
        printf '%s' "$MAX_DATA_LEN"
    fi
}

# All data strings must go here
set_current_len() {
    CURRENT_LEN=$(max_length                                     \
        "$report_title"                                          \
        "$os_name"                                               \
        "$os_kernel"                                             \
        "$net_hostname"                                          \
        "$net_machine_ip"                                        \
        "$net_client_ip"                                         \
        "$net_current_user"                                      \
        "$cpu_model"                                             \
        "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)" \
        "$cpu_hypervisor"                                        \
        "$cpu_freq"                                              \
        "$gpu_model"                                             \
        "$gpu_cores"                                             \
        "$gpu_api"                                               \
        "$gpu_memory"                                            \
        "$gpu_freq"                                              \
        "$gpu_util"                                              \
        "$gpu_load_bar"                                          \
        "$cpu_1min_bar_graph"                                    \
        "$cpu_5min_bar_graph"                                    \
        "$cpu_15min_bar_graph"                                   \
        "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"     \
        "$disk_bar_graph"                                        \
        "$zfs_health"                                            \
        "$root_used_gb/$root_total_gb GB [$disk_percent%]"       \
        "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"   \
        "${mem_bar_graph}"                                       \
        "$last_login_time"                                       \
        "$last_login_ip"                                         \
        "$last_login_ip"                                         \
        "$sys_uptime"                                            \
    )
}

PRINT_HEADER() {
    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))

    local top="┌"
    local bottom="├"
    for (( i = 0; i < length - 2; i++ )); do
        top+="┬"
        bottom+="┴"
    done
    top+="┐"
    bottom+="┤"

    printf '%s\n' "$top"
    printf '%s\n' "$bottom"
}

PRINT_CENTERED_DATA() {
    local max_len=$((CURRENT_LEN+MAX_NAME_LEN-BORDERS_AND_PADDING))
    local text="$1"
    local total_width=$((max_len + 12))

    local text_len=${#text}
    local padding_left=$(( (total_width - text_len) / 2 ))
    local padding_right=$(( total_width - text_len - padding_left ))

    printf "│%${padding_left}s%s%${padding_right}s│\n" "" "$text" ""
}

PRINT_DIVIDER() {
    # either "top" or "bottom", no argument means middle divider
    local side="$1"
    case "$side" in
        "top")
            local left_symbol="├"
            local middle_symbol="┬"
            local right_symbol="┤"
            ;;
        "bottom")
            local left_symbol="└"
            local middle_symbol="┴"
            local right_symbol="┘"
            ;;
        *)
            local left_symbol="├"
            local middle_symbol="┼"
            local right_symbol="┤"
    esac

    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))
    local divider="$left_symbol"
    for (( i = 0; i < length - 3; i++ )); do
        divider+="─"
        if [ "$i" -eq 14 ]; then
            divider+="$middle_symbol"
        fi
    done
    divider+="$right_symbol"
    printf '%s\n' "$divider"
}

PRINT_DATA() {
    local name="$1"
    local data="$2"
    local max_data_len=$CURRENT_LEN

    # Pad name
    local name_len=${#name}
    if (( name_len < MIN_NAME_LEN )); then
        name=$(printf "%-${MIN_NAME_LEN}s" "$name")
    elif (( name_len > MAX_NAME_LEN )); then
        name=$(echo "$name" | cut -c 1-$((MAX_NAME_LEN-3)))...
    else
        name=$(printf "%-${MAX_NAME_LEN}s" "$name")
    fi

    # Truncate or pad data
    local data_len=${#data}
    if (( data_len >= MAX_DATA_LEN || data_len == MAX_DATA_LEN-1 )); then
        data=$(echo "$data" | cut -c 1-$((MAX_DATA_LEN-3-2)))...
    else
        data=$(printf "%-${max_data_len}s" "$data")
    fi

    printf "│ %-${MAX_NAME_LEN}s │ %s │\n" "$name" "$data"
}

PRINT_FOOTER() {
    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))
    local footer="└"
    for (( i = 0; i < length - 3; i++ )); do
        footer+="─"
        if [ "$i" -eq 14 ]; then
            footer+="┴"
        fi
    done
    footer+="┘"
    printf '%s\n' "$footer"
}

bar_graph() {
    local percent
    local num_blocks
    local width=$CURRENT_LEN
    local graph=""
    local used=$1
    local total=$2

    if (( total == 0 )); then
        percent=0
    else
        percent=$(awk -v used="$used" -v total="$total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
    fi

    num_blocks=$(awk -v percent="$percent" -v width="$width" 'BEGIN { printf "%d", (percent / 100) * width }')

    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i = num_blocks; i < width; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

get_ip_addr() {
    # Initialize variables
    ipv4_address=""
    ipv6_address=""

    # Check if ifconfig command exists
    if command -v ifconfig &> /dev/null; then
        # Try to get IPv4 address using ifconfig
        ipv4_address=$(ifconfig | awk '
            /^[a-z]/ {iface=$1}
            iface !~ /^lo/ && iface !~ /^docker/ && iface !~ /^utun/ && /inet / && $2 !~ /^127\./ && !found_ipv4 {found_ipv4=1; print $2}')

        # If IPv4 address not available, try IPv6 using ifconfig
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ifconfig | awk '
                /^[a-z]/ {iface=$1}
                iface !~ /^lo/ && iface !~ /^docker/ && iface !~ /^utun/ && /inet6 / && !found_ipv6 {found_ipv6=1; print $2}')
        fi
    elif command -v ip &> /dev/null; then
        # Try to get IPv4 address using ip addr
        ipv4_address=$(ip -o -4 addr show | awk '
            $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv4++) print a[1]}')

        # If IPv4 address not available, try IPv6 using ip addr
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ip -o -6 addr show | awk '
                $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv6++) print a[1]}')
        fi
    fi

    # If neither IPv4 nor IPv6 address is available, assign "No IP found"
    if [ -z "$ipv4_address" ] && [ -z "$ipv6_address" ]; then
        ip_address="No IP found"
    else
        # Prioritize IPv4 if available, otherwise use IPv6
        ip_address="${ipv4_address:-$ipv6_address}"
    fi

    printf '%s' "$ip_address"
}

format_uptime_seconds() {
    local uptime_seconds="$1"
    local days hours minutes
    local uptime_text=""

    if [ -z "$uptime_seconds" ] || [ "$uptime_seconds" -lt 0 ]; then
        printf '%s' "Unknown"
        return
    fi

    days=$((uptime_seconds / 86400))
    hours=$(((uptime_seconds % 86400) / 3600))
    minutes=$(((uptime_seconds % 3600) / 60))

    if [ "$days" -gt 0 ]; then
        uptime_text="${uptime_text}${days}d "
    fi
    if [ "$hours" -gt 0 ]; then
        uptime_text="${uptime_text}${hours}h "
    fi
    if [ "$minutes" -gt 0 ] || [ -z "$uptime_text" ]; then
        uptime_text="${uptime_text}${minutes}m"
    fi

    printf '%s' "$(echo "$uptime_text" | awk '{$1=$1; print}')"
}

collect_common_network() {
    net_current_user=$(whoami 2>/dev/null || id -un)

    if command -v hostname >/dev/null 2>&1; then
        net_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null)
    fi
    if [ -z "$net_hostname" ] && [ -f /etc/hosts ]; then
        net_hostname=$(grep -w "$(uname -n)" /etc/hosts | awk '{print $2}' | head -n 1)
    fi
    if [ -z "$net_hostname" ]; then
        net_hostname="Not Defined"
    fi

    net_machine_ip=$(get_ip_addr)
    net_client_ip=$(who am i | awk '{print $5}' | tr -d '()')
    if [ -z "$net_client_ip" ]; then
        net_client_ip="Not connected"
    fi
}

collect_linux_data() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_name="${PRETTY_NAME:-Linux}"
    else
        os_name="Linux"
    fi
    os_kernel="$(uname -s) $(uname -r)"

    collect_common_network
    net_dns_ip=($(grep '^nameserver [0-9.]' /etc/resolv.conf 2>/dev/null | awk '{print $2}'))

    if command -v lscpu >/dev/null 2>&1; then
        cpu_model="$(lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
        cpu_hypervisor="$(lscpu | awk -F: '/Hypervisor vendor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
        cpu_cores_per_socket="$(lscpu | awk -F: '/Core\(s\) per socket/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
        cpu_sockets="$(lscpu | awk -F: '/Socket\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
    fi
    if [ -z "$cpu_model" ]; then cpu_model="$(uname -m)"; fi
    if [ -z "$cpu_hypervisor" ]; then cpu_hypervisor="Bare Metal"; fi

    cpu_cores="$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)"
    if [ -z "$cpu_cores" ]; then cpu_cores="1"; fi
    if [ -z "$cpu_cores_per_socket" ]; then cpu_cores_per_socket="$cpu_cores"; fi
    if [ -z "$cpu_sockets" ]; then cpu_sockets="1"; fi

    cpu_freq_mhz=""
    if command -v lscpu >/dev/null 2>&1; then
        cpu_freq_mhz="$(lscpu | awk -F: '/CPU max MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
        if [ -z "$cpu_freq_mhz" ]; then
            cpu_freq_mhz="$(lscpu | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
        fi
    fi
    if [ -z "$cpu_freq_mhz" ] && [ -f /proc/cpuinfo ]; then
        cpu_freq_mhz="$(awk -F: '/cpu MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)"
    fi
    if [ -n "$cpu_freq_mhz" ]; then
        cpu_freq="$(awk -v mhz="$cpu_freq_mhz" 'BEGIN { printf "%.2f GHz", mhz / 1000 }')"
    else
        cpu_freq="-"
    fi

    gpu_model="-"
    gpu_cores="-"
    gpu_api="-"
    gpu_memory="-"
    gpu_freq="-"
    gpu_util="-"
    gpu_util_pct=""
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 | awk '{$1=$1; print}')
        gpu_sms=$(nvidia-smi --query-gpu=multiprocessor_count --format=csv,noheader,nounits 2>/dev/null | head -n 1 | awk '{$1=$1; print}')
        gpu_mem_line=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        gpu_util_val=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1 | awk '{$1=$1; print}')
        gpu_clock_mhz=$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | head -n 1 | awk '{$1=$1; print}')
        gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 | awk '{$1=$1; print}')

        if [ -n "$gpu_sms" ]; then gpu_cores="${gpu_sms} (SM)"; fi
        if [ -n "$gpu_mem_line" ]; then
            gpu_memory=$(echo "$gpu_mem_line" | awk -F, '{gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); printf "%s/%s MiB", $1, $2}')
        fi
        if [ -n "$gpu_util_val" ]; then
            gpu_util_pct=$(echo "$gpu_util_val" | awk '{print $1 + 0}')
            gpu_util=$(awk -v pct="$gpu_util_pct" 'BEGIN { printf "%.2f%%", pct }')
        fi
        if [ -n "$gpu_clock_mhz" ]; then
            gpu_freq=$(awk -v mhz="$gpu_clock_mhz" 'BEGIN { printf "%.2f GHz", mhz / 1000 }')
        fi
        if [ -n "$gpu_driver" ]; then gpu_api="NVIDIA ${gpu_driver}"; fi
    elif command -v lspci >/dev/null 2>&1; then
        gpu_model=$(lspci | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}')
    fi
    if [ -z "$gpu_model" ]; then gpu_model="-"; fi
    if [ -z "$gpu_cores" ]; then gpu_cores="-"; fi
    if [ -z "$gpu_api" ]; then gpu_api="-"; fi
    if [ -z "$gpu_memory" ]; then gpu_memory="-"; fi
    if [ -z "$gpu_freq" ]; then gpu_freq="-"; fi
    if [ -z "$gpu_util" ]; then gpu_util="-"; fi

    load_values=$(uptime | awk -F'load average: ' 'NF>1 {gsub(/,/, "", $2); print $2}')
    if [ -z "$load_values" ]; then
        load_values=$(uptime | awk -F'load averages?: ' 'NF>1 {gsub(/,/, "", $2); print $2}')
    fi
    load_avg_1min=$(echo "$load_values" | awk '{print $1}')
    load_avg_5min=$(echo "$load_values" | awk '{print $2}')
    load_avg_15min=$(echo "$load_values" | awk '{print $3}')
    if [ -z "$load_avg_1min" ]; then load_avg_1min="0"; fi
    if [ -z "$load_avg_5min" ]; then load_avg_5min="0"; fi
    if [ -z "$load_avg_15min" ]; then load_avg_15min="0"; fi

    if [ -f /proc/meminfo ]; then
        mem_total=$(awk '/MemTotal/ {print $2; exit}' /proc/meminfo)
        mem_available=$(awk '/MemAvailable/ {print $2; exit}' /proc/meminfo)
    fi
    if [ -z "$mem_total" ]; then mem_total="1"; fi
    if [ -z "$mem_available" ]; then mem_available="0"; fi
    mem_used=$((mem_total - mem_available))
    mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { if (total == 0) print "0.00"; else printf "%.2f", (used / total) * 100 }')
    mem_total_gb=$(awk -v total="$mem_total" 'BEGIN { printf "%.2f", total / (1024 * 1024) }')
    mem_used_gb=$(awk -v used="$mem_used" 'BEGIN { printf "%.2f", used / (1024 * 1024) }')

    if command -v zfs >/dev/null 2>&1 && [ -f /proc/mounts ] && grep -q "zfs" /proc/mounts; then
        zfs_present=1
        zfs_health=$(zpool status -x zroot 2>/dev/null | grep -q "is healthy" && echo "HEALTH O.K.")
        zfs_available=$(zfs get -o value -Hp available "$zfs_filesystem" 2>/dev/null)
        zfs_used=$(zfs get -o value -Hp used "$zfs_filesystem" 2>/dev/null)
        zfs_available_gb=$(awk -v available="$zfs_available" 'BEGIN { printf "%.2f", available / (1024 * 1024 * 1024) }')
        zfs_used_gb=$(awk -v used="$zfs_used" 'BEGIN { printf "%.2f", used / (1024 * 1024 * 1024) }')
        disk_percent=$(awk -v used="$zfs_used" -v available="$zfs_available" 'BEGIN { if (available == 0) print "0.00"; else printf "%.2f", (used / available) * 100 }')
    else
        root_partition="/"
        root_used=$(df -m "$root_partition" | awk 'NR==2 {print $3}')
        root_total=$(df -m "$root_partition" | awk 'NR==2 {print $2}')
        root_total_gb=$(awk -v total="$root_total" 'BEGIN { printf "%.2f", total / 1024 }')
        root_used_gb=$(awk -v used="$root_used" 'BEGIN { printf "%.2f", used / 1024 }')
        disk_percent=$(awk -v used="$root_used" -v total="$root_total" 'BEGIN { if (total == 0) print "0.00"; else printf "%.2f", (used / total) * 100 }')
    fi

    if command -v lastlog >/dev/null 2>&1; then
        last_login=$(lastlog -u "$USER")
        last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')
        if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            last_login_ip_present=1
            last_login_time=$(echo "$last_login" | awk 'NR==2 {print $6, $7, $10, $8}')
        else
            last_login_time=$(echo "$last_login" | awk 'NR==2 {print $4, $5, $8, $6}')
        fi
        if echo "$last_login_time" | grep -q "in\\*\\*" || [ -z "$last_login_time" ]; then
            last_login_time="Never logged in"
        fi
    else
        last_login_time="Unknown"
        last_login_ip=""
    fi

    if [ -f /proc/uptime ]; then
        uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
        sys_uptime=$(format_uptime_seconds "$uptime_seconds")
    else
        sys_uptime=$(uptime 2>/dev/null | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
        if [ -z "$sys_uptime" ]; then sys_uptime="Unknown"; fi
    fi
}

collect_macos_data() {
    os_name="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    if [ -z "$os_name" ]; then os_name="macOS"; fi
    os_kernel="$(uname -s) $(uname -r)"

    collect_common_network
    net_dns_ip=($(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/ {print $3}' | awk '!seen[$0]++'))

    cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    if [ -z "$cpu_model" ]; then cpu_model=$(sysctl -n hw.model 2>/dev/null); fi
    if [ -z "$cpu_model" ]; then cpu_model="Apple Silicon"; fi
    cpu_hypervisor="Bare Metal"

    cpu_cores=$(sysctl -n hw.logicalcpu 2>/dev/null)
    if [ -z "$cpu_cores" ]; then cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null); fi
    if [ -z "$cpu_cores" ]; then cpu_cores="1"; fi
    cpu_cores_per_socket="$cpu_cores"
    cpu_sockets="1"

    cpu_freq_hz=$(sysctl -n hw.cpufrequency 2>/dev/null)
    if [ -z "$cpu_freq_hz" ] || [ "$cpu_freq_hz" = "0" ]; then
        cpu_freq_hz=$(sysctl -n hw.cpufrequency_max 2>/dev/null)
    fi
    if [ -n "$cpu_freq_hz" ] && [ "$cpu_freq_hz" != "0" ]; then
        cpu_freq=$(awk -v hz="$cpu_freq_hz" 'BEGIN { printf "%.2f GHz", hz / 1000000000 }')
    else
        cpu_freq=$(echo "$cpu_model" | awk 'match($0, /[0-9.]+ ?GHz/) {print substr($0, RSTART, RLENGTH)}')
        if [ -z "$cpu_freq" ]; then
            cpu_freq="N/A (Apple Silicon)"
        fi
    fi

    gpu_profile="$(system_profiler SPDisplaysDataType 2>/dev/null)"
    gpu_model=$(echo "$gpu_profile" | awk -F': ' '/Chipset Model/ {print $2; exit}')
    gpu_cores=$(echo "$gpu_profile" | awk -F': ' '/Total Number of Cores/ {print $2; exit}')
    gpu_api=$(echo "$gpu_profile" | awk -F': ' '/Metal Support/ {print $2; exit}')
    gpu_memory=$(echo "$gpu_profile" | awk -F': ' '/VRAM \(Total\)|VRAM \(Dynamic, Max\)|VRAM/ {print $2; exit}')
    gpu_freq="-"
    gpu_util="-"
    gpu_util_pct=""

    if [ -z "$gpu_model" ]; then gpu_model="Apple GPU"; fi
    if [ -z "$gpu_cores" ]; then gpu_cores="-"; fi
    if [ -z "$gpu_api" ]; then gpu_api="Metal"; fi
    if [ -z "$gpu_memory" ]; then gpu_memory="Unified"; fi

    collect_macos_high_fidelity_data

    load_values=$(sysctl -n vm.loadavg 2>/dev/null | awk '{gsub(/[{}]/, "", $0); print $1, $2, $3}')
    load_avg_1min=$(echo "$load_values" | awk '{print $1}')
    load_avg_5min=$(echo "$load_values" | awk '{print $2}')
    load_avg_15min=$(echo "$load_values" | awk '{print $3}')
    if [ -z "$load_avg_1min" ]; then load_avg_1min="0"; fi
    if [ -z "$load_avg_5min" ]; then load_avg_5min="0"; fi
    if [ -z "$load_avg_15min" ]; then load_avg_15min="0"; fi

    mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    page_size=$(vm_stat | awk '/page size of/ {print $8; exit}')
    pages_free=$(vm_stat | awk '/Pages free/ {gsub(/\./, "", $NF); print $NF; exit}')
    pages_inactive=$(vm_stat | awk '/Pages inactive/ {gsub(/\./, "", $NF); print $NF; exit}')
    pages_speculative=$(vm_stat | awk '/Pages speculative/ {gsub(/\./, "", $NF); print $NF; exit}')
    if [ -z "$pages_free" ]; then pages_free="0"; fi
    if [ -z "$pages_inactive" ]; then pages_inactive="0"; fi
    if [ -z "$pages_speculative" ]; then pages_speculative="0"; fi
    if [ -z "$page_size" ]; then page_size="4096"; fi

    mem_available_bytes=$(((pages_free + pages_inactive + pages_speculative) * page_size))
    if [ -z "$mem_total_bytes" ] || [ "$mem_total_bytes" -eq 0 ]; then mem_total_bytes="1"; fi
    mem_used_bytes=$((mem_total_bytes - mem_available_bytes))
    if [ "$mem_used_bytes" -lt 0 ]; then mem_used_bytes=0; fi

    mem_total=$((mem_total_bytes / 1024))
    mem_used=$((mem_used_bytes / 1024))
    if [ "$mem_total" -le 0 ]; then mem_total="1"; fi
    mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { if (total == 0) print "0.00"; else printf "%.2f", (used / total) * 100 }')
    mem_total_gb=$(awk -v total="$mem_total_bytes" 'BEGIN { printf "%.2f", total / (1024 * 1024 * 1024) }')
    mem_used_gb=$(awk -v used="$mem_used_bytes" 'BEGIN { printf "%.2f", used / (1024 * 1024 * 1024) }')

    root_partition="/"
    root_used=$(df -k "$root_partition" | awk 'NR==2 {print $3}')
    root_total=$(df -k "$root_partition" | awk 'NR==2 {print $2}')
    if [ -z "$root_used" ]; then root_used=0; fi
    if [ -z "$root_total" ] || [ "$root_total" -eq 0 ]; then root_total=1; fi
    root_total_gb=$(awk -v total="$root_total" 'BEGIN { printf "%.2f", total / (1024 * 1024) }')
    root_used_gb=$(awk -v used="$root_used" 'BEGIN { printf "%.2f", used / (1024 * 1024) }')
    disk_percent=$(awk -v used="$root_used" -v total="$root_total" 'BEGIN { printf "%.2f", (used / total) * 100 }')

    last_entry=$(last -n 1 "$USER" 2>/dev/null | awk 'NR==1')
    if [ -z "$last_entry" ] || echo "$last_entry" | grep -q "^wtmp begins"; then
        last_login_time="Never logged in"
        last_login_ip=""
    else
        last_login_ip=$(echo "$last_entry" | awk '{print $3}')
        last_login_time=$(echo "$last_entry" | awk '{print $4, $5, $6, $7}')
        if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            last_login_ip_present=1
        fi
    fi

    boot_epoch=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[ ,}]+' '{print $4}')
    if [ -n "$boot_epoch" ]; then
        uptime_seconds=$(( $(date +%s) - boot_epoch ))
        sys_uptime=$(format_uptime_seconds "$uptime_seconds")
    else
        sys_uptime="Unknown"
    fi
}

collect_macos_high_fidelity_data() {
    local pm_output=""
    local cpu_avg_mhz=""
    local cpu_nominal_pct=""
    local gpu_active=""
    local gpu_active_pct=""
    local gpu_freq_mhz=""
    local sample_interval_ms="$machine_report_high_fidelity_interval_ms"

    if [ "$machine_report_high_fidelity" != "1" ]; then
        return
    fi
    if ! command -v powermetrics >/dev/null 2>&1; then
        return
    fi
    if ! [[ "$sample_interval_ms" =~ ^[0-9]+$ ]] || [ "$sample_interval_ms" -lt 50 ]; then
        sample_interval_ms=200
    fi

    if [ "$EUID" -eq 0 ]; then
        pm_output=$(powermetrics --samplers cpu_power,gpu_power -n 1 -i "$sample_interval_ms" 2>/dev/null || true)
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        pm_output=$(sudo -n powermetrics --samplers cpu_power,gpu_power -n 1 -i "$sample_interval_ms" 2>/dev/null || true)
    else
        if [ "$cpu_freq" = "N/A (Apple Silicon)" ]; then
            cpu_freq="N/A (sudo)"
        fi
        if [ "$gpu_freq" = "-" ]; then
            gpu_freq="N/A (sudo)"
        fi
        if [ "$gpu_util" = "-" ]; then
            gpu_util="N/A (sudo)"
        fi
        gpu_util_pct=""
        return
    fi

    if [ -z "$pm_output" ]; then
        return
    fi

    cpu_avg_mhz=$(echo "$pm_output" | awk -F': ' '/CPU Average frequency/ && $2 ~ /MHz/ {gsub(/[^0-9.]/, "", $2); print $2; exit}')
    cpu_nominal_pct=$(echo "$pm_output" | awk -F': ' '/CPU Average frequency as fraction of nominal/ {gsub(/[^0-9.]/, "", $2); print $2; exit}')
    if [ -n "$cpu_avg_mhz" ]; then
        cpu_freq=$(awk -v mhz="$cpu_avg_mhz" 'BEGIN { printf "%.2f GHz (live)", mhz / 1000 }')
    elif [ -n "$cpu_nominal_pct" ]; then
        cpu_freq="${cpu_nominal_pct}% nominal"
    fi

    gpu_active=$(echo "$pm_output" | awk -F': ' '/GPU HW active residency|GPU active residency|GPU duty cycle/ {gsub(/^[ \t]+/, "", $2); print $2}')
    if [ -n "$gpu_active" ]; then
        gpu_active_pct=$(echo "$gpu_active" | awk '
            {
                line=$0
                while (match(line, /[0-9]+([.][0-9]+)?%/)) {
                    pct=substr(line, RSTART, RLENGTH-1) + 0
                    if (pct >= 0 && pct <= 100) {
                        printf "%.2f", pct
                        exit
                    }
                    line=substr(line, RSTART + RLENGTH)
                }
            }')
        if [ -n "$gpu_active_pct" ]; then
            gpu_util="${gpu_active_pct}%"
            gpu_util_pct="$gpu_active_pct"
        else
            gpu_util="N/A"
            gpu_util_pct=""
        fi
    fi

    gpu_freq_mhz=$(echo "$pm_output" | awk '
        /GPU/ && /MHz/ {
            line=$0
            while (match(line, /[0-9]+([.][0-9]+)?[[:space:]]*MHz/)) {
                token=substr(line, RSTART, RLENGTH)
                gsub(/[^0-9.]/, "", token)
                val=token + 0
                if (val > 0) { print val; exit }
                line=substr(line, RSTART + RLENGTH)
            }
        }')
    if [ -n "$gpu_freq_mhz" ]; then
        gpu_freq=$(awk -v mhz="$gpu_freq_mhz" 'BEGIN { printf "%.2f GHz", mhz / 1000 }')
    fi
}

OS_TYPE=$(uname -s)
if [ "$OS_TYPE" = "Darwin" ]; then
    collect_macos_data
else
    collect_linux_data
fi

# Set current length before graphs get calculated
set_current_len

# Create graphs
cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")

if [ -n "$gpu_util_pct" ]; then
    gpu_load_bar=$(bar_graph "$gpu_util_pct" "100")
else
    gpu_load_bar="-"
fi

mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")

if [ $zfs_present -eq 1 ]; then
    disk_bar_graph=$(bar_graph "$zfs_used" "$zfs_available")
else
    disk_bar_graph=$(bar_graph "$root_used" "$root_total")
fi

# Machine Report
PRINT_HEADER
PRINT_CENTERED_DATA "$report_title"
PRINT_CENTERED_DATA "TR-100 MACHINE REPORT"
PRINT_DIVIDER "top"
PRINT_DATA "OS" "$os_name"
PRINT_DATA "KERNEL" "$os_kernel"
PRINT_DIVIDER
PRINT_DATA "HOSTNAME" "$net_hostname"
PRINT_DATA "MACHINE IP" "$net_machine_ip"
PRINT_DATA "CLIENT  IP" "$net_client_ip"

for dns_num in "${!net_dns_ip[@]}"; do
    PRINT_DATA "DNS  IP $(($dns_num + 1))" "${net_dns_ip[dns_num]}"
done

PRINT_DATA "USER" "$net_current_user"
PRINT_DIVIDER
PRINT_DATA "CPU MODEL" "$cpu_model"
PRINT_DATA "CPU CORES" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)"
PRINT_DATA "HYPERVISOR" "$cpu_hypervisor"
PRINT_DATA "CPU FREQ" "$cpu_freq"
PRINT_DATA "LOAD  1m" "$cpu_1min_bar_graph"
PRINT_DATA "LOAD  5m" "$cpu_5min_bar_graph"
PRINT_DATA "LOAD 15m" "$cpu_15min_bar_graph"
PRINT_DIVIDER
PRINT_DATA "GPU MODEL" "$gpu_model"
PRINT_DATA "GPU CORES" "$gpu_cores"
PRINT_DATA "GPU API" "$gpu_api"
PRINT_DATA "GPU MEMORY" "$gpu_memory"
PRINT_DATA "GPU FREQ" "$gpu_freq"
PRINT_DATA "GPU UTIL" "$gpu_util"
PRINT_DATA "GPU LOAD" "$gpu_load_bar"

if [ $zfs_present -eq 1 ]; then
    PRINT_DIVIDER
    PRINT_DATA "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
    PRINT_DATA "DISK USAGE" "$disk_bar_graph"
    PRINT_DATA "ZFS HEALTH" "$zfs_health"
else
    PRINT_DIVIDER
    PRINT_DATA "VOLUME" "$root_used_gb/$root_total_gb GB [$disk_percent%]"
    PRINT_DATA "DISK USAGE" "$disk_bar_graph"
fi

PRINT_DIVIDER
PRINT_DATA "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
PRINT_DATA "USAGE" "${mem_bar_graph}"
PRINT_DIVIDER
PRINT_DATA "LAST LOGIN" "$last_login_time"

if [ $last_login_ip_present -eq 1 ]; then
    PRINT_DATA "" "$last_login_ip"
fi

PRINT_DATA "UPTIME" "$sys_uptime"
PRINT_DIVIDER "bottom"
