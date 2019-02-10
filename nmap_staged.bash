
# Adapted from https://security.stackexchange.com/questions/170400/nmap-top-ports-range-selection
top_ports() {
    if [[ -z $2 ]]; then printf "usage: $FUNCNAME PROTOCOL QUANTITY\n\nEXAMPLE: top-ports udp 32\n"; return 1; fi
    field='$2'
    udpflag=''
    # if udp selected, set the appropriate nmap flags
    [[ $1 == "udp" ]] && field='$4' && udpflag='-sU'
    # sudo required for UDP output
    sudo nmap $udpflag -oG - -v --top-ports $2 2>/dev/null | awk -F'[);]' "/Ports/{print ${field}}"
}

PORT_RANGES=(100 1000 10000)
export PORT_RANGES=(0 "${PORT_RANGES[@]}" 65535)
export LENGTH=${#PORT_RANGES[@]}
export DATEFORMAT="+%Y-%m-%d_%H%M%S%N";

nmap_staged() {
    EXIT=0
    
    # check valid number of arguments
    if [[ -z $2 ]]; then
        echo "Error: $FUNCNAME expects 2 arguments.";
        EXIT=1
    fi
    
    PROTOCOL=$1
    HOSTSFILE=$2
    mkdir -p nmap
    
    # check valid protocol
    case "$PROTOCOL" in
        tcp)
            PROTOCOLFLAG="-sS"
            ;;
        udp)
            PROTOCOLFLAG="-sU"
            ;;
        *)
            echo "Error: PROTOCOL should be tcp or udp.";
            EXIT=2
    esac
    
    # check file exists
    if [[ ! -f "$HOSTSFILE" ]]; then
        echo "Error: HOSTSFILE not valid: \"$HOSTSFILE\"."
        EXIT=3
    fi
    
    # failure output
    if [[ $EXIT != 0 ]]; then
        echo
        echo "    Perform a full TCP or UDP Nmap scan in stages on a hostsfile."
        echo "    Alexi Chiotis - Mercury ISS - 2018-08-06"
        echo
        echo "    USAGE: $FUNCNAME PROTOCOL HOSTSFILE"
        echo
        return $EXIT
    fi
    
    # staged tcp scan on top-ports indicated in PORT_RANGES list
    for (( i = 1; i < ${LENGTH}; i++ )); do
        DATETIME="$(date ${DATEFORMAT})"
        exclude_arg=''
        
        if [[ ${PORT_RANGES[$i-1]} -ne '0' ]]; then
            echo Exclude top ports: "${PORT_RANGES[$i-1]}"
            exclude_arg="--exclude-ports $(top_ports "$PROTOCOL" ${PORT_RANGES[$i-1]})"
        fi
        
        # BUG check the final scan is being performed, seems like excluding all ports???
        # nmap output: WARNING: a TCP scan type was requested, but no tcp ports were specified.  Skipping this scan type.
        #set -x
        OUTFILENAME=nmap/$(basename "$HOSTSFILE").stage-${i}-top-"$PROTOCOL"-${PORT_RANGES[$i]}.${DATETIME}
        sudo nmap -Pn "$PROTOCOLFLAG" -sV --top-ports "${PORT_RANGES[$i]}" $exclude_arg -iL "$HOSTSFILE" -oA "$OUTFILENAME"
        #set +x
    done
}

