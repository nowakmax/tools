#!/bin/bash

get_sata_disks() {
        ls /dev/ | grep -e "^da[0-9]" | grep -v 'p'
}

get_nvme_disks() {
        ls /dev/ | grep -e "^nvme[0-9]$"
}

collect_smart() {
        for disk in $(get_sata_disks); do
                smartctl -a /dev/${disk} > /tmp/${disk}.smart.txt
        done
}

collect_smart_nvme() {
        for disk in $(get_nvme_disks); do
                smartctl -a /dev/${disk} > /tmp/${disk}.smart.txt
        done
}

report() {
        echo "# TYPE smart_start_stop_cycles_read_total counter"
        echo "# TYPE smart_load_unload_cycles_read_total counter"
        echo "# TYPE smart_non_medium_error_count_total counter"
        echo "# HELP smart_gb_read_total in gigabytes 10^9bytes"
        echo "# TYPE smart_gb_read_total counter"
        echo "# HELP smart_gb_write_total in gigabytes 10^9bytes"
        echo "# TYPE smart_gb_write_total counter"
        echo "# HELP smart_gb_verify_total in gigabytes 10^9bytes"
        echo "# TYPE smart_gb_verify_total counter"
        for disk in $(get_sata_disks); do
                curr_temp=$(cat /tmp/${disk}.smart.txt | grep 'Current Drive Temperature' | sed -e 's/.*: *//g' | sed 's/ *C//g')
                trip_temp=$(cat /tmp/${disk}.smart.txt | grep 'Drive Trip Temperature' | sed -e 's/.*: *//g' | sed 's/ *C//g')
                start_stop_cycles=$(cat /tmp/${disk}.smart.txt | grep 'Accumulated start-stop cycles:' | sed -e 's/.*: *//g' | sed 's/ *//g')
                load_unload_cycles=$(cat /tmp/${disk}.smart.txt | grep 'Accumulated load-unload cycles:' | sed -e 's/.*: *//g' | sed 's/ *//g')
                non_medium=$(cat /tmp/${disk}.smart.txt | grep 'Non-medium error count:' | sed -e 's/.*: *//g' | sed 's/ *//g')
                gb_read=$(cat /tmp/${disk}.smart.txt | grep '^read:' | awk '{print $7}')
                gb_write=$(cat /tmp/${disk}.smart.txt | grep '^write:' | awk '{print $7}')
                gb_verify=$(cat /tmp/${disk}.smart.txt | grep '^verify:' | awk '{print $7}')
                [ -z "${gb_read}" ] && gb_read="0.0"
                [ -z "${gb_write}" ] && gb_write="0.0"
                [ -z "${gb_verify}" ] && gb_verify="0.0"
                smart_ok="1.0"
                cat /tmp/${disk}.smart.txt | grep -q '^SMART Health Status: OK'
                if [ "$?"  -ne "0" ]; then
                        smart_ok="0.0"
                fi
                echo "smart_current_temperature_celsius{drive=\"$disk\"} $curr_temp"
                echo "smart_trip_temperature_celsius{drive=\"$disk\"} $trip_temp"
                echo "smart_start_stop_cycles_total{drive=\"$disk\"} $start_stop_cycles"
                echo "smart_load_unload_cycles_total{drive=\"$disk\"} $load_unload_cycles"
                echo "smart_non_medium_error_count_total{drive=\"$disk\"} $non_medium"
                echo "smart_gb_read_total{drive=\"$disk\"} $gb_read"
                echo "smart_gb_write_total{drive=\"$disk\"} $gb_write"
                echo "smart_gb_verify_total{drive=\"$disk\"} $gb_verify"
                echo "smart_ok{drive=\"$disk\"} $smart_ok"
        done
}

report_nvme() {
        for disk in $(get_nvme_disks); do
                curr_temp=$(cat /tmp/${disk}.smart.txt | grep '^Temperature' | sed -e 's/.*: *//g' | sed 's/ *C.*//g')
                smart_ok="1.0"
                cat /tmp/${disk}.smart.txt | grep -q '^Critical Warning:                   0x00'
                if [ "$?"  -ne "0" ]; then
                        smart_ok="0.0"
                fi
                echo "smart_current_temperature_celsius{drive=\"$disk\"} $curr_temp"
                echo "smart_ok{drive=\"$disk\"} $smart_ok"
        done
}

collect_smart
collect_smart_nvme
report > /var/tmp/node_exporter/smart.$$
report_nvme >> /var/tmp/node_exporter/smart.$$
mv /var/tmp/node_exporter/smart.$$ /var/tmp/node_exporter/smart.prom
