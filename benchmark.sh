#!/bin/bash

#==============================================================================
# Goodservers benchmark v0.1
#
# Copyright (c) 2013 Mario Gutierrez <mario@mgutz.com>
# Modified by Tom Wagner <tomas.wagner@gmail.com> for https://vpscomp.com
#
# Licensed under The MIT License
#==============================================================================


# Quick benchmark, always run
function bench_quick {
    isNumber='^[0-9\.]+$'

    # Test Status
    fail=false

    jsonOutput="{"
    local test_file=vpsbench__$$
    local tar_file=tarfile
    local now=$(date +"%m/%d/%Y")

    printf "==========================================\n"
    printf "GoodServers.io benchmark v0.1 - Welcome\n"
    printf "==========================================\n"

    echo -n "Getting CPU basic info ... "

    local cpuName=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
    if ! [[ -z "$cpuName" ]] ; then
        jsonOutput="$jsonOutput \"cpuName\":\"$cpuName\""
    else
        fail=true
    fi

    local cpuFrequency=$( awk -F: ' /cpu MHz/ {cpuFrequency=$2} END {print cpuFrequency}' /proc/cpuinfo | sed 's/ //g' )
    if [[ $cpuFrequency =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"cpuFrequency\":$cpuFrequency"
    else
        fail=true
    fi

    local cpuCache=$( awk -F: ' /cache size/ {cpuCache=$2} END {print cpuCache}' /proc/cpuinfo | sed "s/[^0-9]//g" )
    if [[ $cpuCache =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"cpuCache\":$cpuCache"
    else
        fail=true
    fi

    local cpuCacheUnits=$( awk -F: ' /cache size/ {cpuCache=$2} END {print cpuCache}' /proc/cpuinfo | sed "s/[^a-zA-Z]//g" )
    if ! [[ -z "$cpuCacheUnits" ]] ; then
        jsonOutput="$jsonOutput, \"cpuCacheUnits\":\"$cpuCacheUnits\""
    fi

    local cpu=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo | sed 's/ //g'  )
    if [[ $cpu =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"cpu\":$cpu"
    else
        fail=true
    fi

    echo Done

    echo -n "Getting Ram basic info ... "

    local ram=$( free -m | awk 'NR==2 {print $2}' | sed 's/ //g'  )
    if [[ $ram =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"ram\":$ram"
    else
        fail=true
    fi

    echo Done

    echo -n "Getting Swap basic info ... "

    local swap=$( free -m | awk 'NR==4 {print $2}' | sed 's/ //g'  )
    if [[ $swap =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"swap\":$swap"
    else
        fail=true
    fi

    echo Done

    local uptimeHuman=$(uptime|awk '{ $1=$2=$(NF-6)=$(NF-5)=$(NF-4)=$(NF-3)=$(NF-2)=$(NF-1)=$NF=""; print }')
    local uptime=$( cat /proc/uptime | awk 'NR==1 {print $1}' | sed 's/ //g'  )
    if [[ $uptime =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"uptime\":$uptime"
    else
        fail=true
    fi

    echo -n "Benching I/O speed ... "
    local io=$( ( dd if=/dev/zero of=$test_file bs=64k count=16k conv=fdatasync && rm -f $test_file ) 2>&1 | awk -F, '{io=$NF} END { print io}' )

    ioSpeed=$(echo $io | sed "s/[^0-9]//g")
    if [[ $ioSpeed =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"ioSpeed\":$ioSpeed"
    else
        fail=true
    fi

    ioSpeedUnit=$(echo $io | sed "s/[^a-zA-Z\/]//g" | sed 's/ //g')
    if ! [[ -z "$ioSpeedUnit" ]] ; then
        jsonOutput="$jsonOutput, \"ioSpeedUnit\":\"$ioSpeedUnit\""
    fi
    echo Done

    echo -n "Benching CPU. Bzipping 25MB file ... "
    dd if=/dev/urandom of=$tar_file bs=1024 count=25000 >>/dev/null 2>&1
    local bzipSpeed=$( (/usr/bin/time -f "%es" tar cfj $tar_file.bz2 $tar_file) 2>&1 )
    rm -f tarfile*

    bzipSpeedTest=$(echo $bzipSpeed | sed "s/[^0-9\.]//g")
    if [[ $bzipSpeedTest =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"bzipSpeedTest\":$bzipSpeedTest"
    else
        fail=true
    fi

    bzipSpeedTestUnit=$(echo $bzipSpeed | sed "s/[^a-zA-Z\/]//g" | sed 's/ //g')
    if ! [[ -z "$bzipSpeedTestUnit" ]] ; then
        jsonOutput="$jsonOutput, \"bzipSpeedTestUnit\":\"$bzipSpeedTestUnit\""
    fi
    echo Done

    echo -n "Benching network speed. Downloading 100MB file ... "
    local downloadSpeed=$( _dl http://cachefly.cachefly.net/100mb.test )

    downloadSpeed=$(echo $downloadSpeed | sed "s/[^0-9\.]//g")
    if [[ $downloadSpeed =~ $isNumber ]] ; then
        jsonOutput="$jsonOutput, \"downloadSpeed\":$downloadSpeed"
    else
        fail=true
    fi

    networkSpeedUnit=$(echo $downloadSpeed | sed "s/[^a-zA-Z\/]//g" | sed 's/ //g')
    if ! [[ -z "$networkSpeedUnit" ]] ; then
        jsonOutput="$jsonOutput, \"downloadSpeedUnit\":\"$networkSpeedUnit\""
    fi
    echo Done

    virtualization=$(virt-what)
    if ! [[ -z "$virtualization" ]] ; then
        jsonOutput="$jsonOutput, \"virtualization\":\"$virtualization\""
    fi

    jsonOutput="$jsonOutput }"

    echo $jsonOutput

    #if [ "$fail" = true ] ; then
    #    printf "Sorry, your benchmark is uncomplete. To create complete test, you need to install:\n"
    #    printf "time bzip2 virt-what\n\n"
    #    printf "If error occured, please contact us at https://vpscomp.com"

    #else
    #    upload_results
    #fi
    upload_results

    cat <<USER_INFO
Your results @ $now:
==========================================
Virtualization: $virtualization
CPU: $cpuName L2 cache: $cpuCache $cpuCacheUnits
Number of cores: $cpu
CPU frequency: $cpuFrequency MHz
Total amount of RAM: $ram MB
Total amount of swap: $swap MB
System uptime: $uptimeHuman
I/O speed: $io
Bzip 25MB: $bzipSpeed
Download 100MB file: $downloadSpeed


USER_INFO
}

function _dl {
    wget -O /dev/null "$1" 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}'
}


# Display usage.
function usage {
    cat <<USAGE
Usage: vpscompbench [OPTION...]

USAGE
}


function upload_results {
    benchmarkUrl='https://api.goodservers.io/benchmark/upload/'
    echo -n "Uploading result to goodservers.io ... "

    httpStatusCode=$( wget -O- --post-data="$jsonOutput" --header=Content-Type:application/json "$benchmarkUrl$variantId" 2>&1 | grep -F HTTP | cut -d ' ' -f 6 )
    # if fails, try curl
    if ! [[ $httpStatusCode -eq 200 ]] ; then
        httpStatusCode=$( curl -o /dev/null --silent --write-out '%{http_code}\n' \
        -i \
        -H "Accept: application/json" \
        -H "Content-Type:application/json" \
        -X POST --data "$jsonOutput" "$benchmarkUrl$variantId" )
    fi

    if [[ $httpStatusCode -eq 200 ]] ; then
        echo Done
        printf "Thank you for your benchmark test\n\n"
    else
        echo Failed
        printf "Something went wrong, please write us."
    fi
}


# Parse command line options
while getopts ":u:" opt; do
    case "$opt" in
        u)
            variantId=$OPTARG
            bench_quick
            ;;
        ?)
            usage
            exit 2
            ;;
    esac
done

# main
