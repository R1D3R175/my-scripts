#!/bin/bash

function help() {
    echo -e "Usage:
    $(basename $0) [ -l, --list ] [ -v, --verbose ] [ -h, --help ] \e[4mnetwork_interface"
    
    exit 0
}

function list_interfaces() {
    local network_interfaces=($(ls /sys/class/net))
    
    echo -e "${RED_BOLD}Your Network Interfaces are:${RESET}"
    
    for ((i = 1; i <= ${#network_interfaces[@]}; i++));
    do
        echo -e "${GREEN_BOLD}$i. ${BG_RED_FG_WHITE}${network_interfaces[i-1]}${RESET}"
    done
    
    exit 0
}

RESET="\e[0m"
RED_BOLD="\e[1;31m"
GREEN="\e[32m"
GREEN_BOLD="\e[1;32m"
BG_RED_FG_WHITE="\e[41;1;37m"

SHORT=l,v,h
LONG=list,verbose,help
OPTS=$(getopt --name suricata-docker-setup --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

VERBOSE="/dev/null"

while :
do
    case "$1" in
        -l | --list )
            list_interfaces
        ;;
        -v | --verbose )
            VERBOSE="/dev/stdout"
            shift 2
        ;;
        -h | --help )
            help
        ;;
        -- )
            shift
            break
        ;;
        * )
            echo -e "${RED_BOLD} What the heck is even this option: ${RESET}${BG_RED_FG_WHITE}$1${RESET}"
            help
        ;;
    esac
done

if [ "$#" -eq 0 ];
then
    echo -e "${RED_BOLD}You must pass the interface name to the script!${RESET}"
    help
fi

network_interfaces=($(ls /sys/class/net))
passed=false
for network_interface in "${network_interfaces[@]}";
do
    if [ "$1" = "$network_interface" ];
    then
        passed=true
        break
    fi
done

if [ "$passed" = false ];
then
    echo -e "${RED_BOLD}You don't have a Network Interface called $1. "
    
    list_interfaces
fi

if [ "$(id -u)" -ne 0 ];
then
    echo -e "${RED_BOLD}How the heck I'm not root in a VulnBox?!"
    echo -e "Run me as the ${BG_RED_FG_WHITE}root${RESET} ${RED_BOLD}user${RESET}"
    exit 0
fi

echo -e "${RED_BOLD}Creating /suricata... ${RESET}"
mkdir /suricata &> "$VERBOSE"
cd /suricata 

echo -e "${RED_BOLD}Creating sub-directories for Docker Volumes: ${RESET}\n\
	${GREEN}- /suricata/etc/ ${RESET}\n\
	${GREEN}- /suricata/lib/ ${RESET}\n\
	${GREEN}- /suricata/log/ ${RESET}"
mkdir {etc,lib,log} &> "$VERBOSE"

echo -e "${RED_BOLD}Running Suricata container (detatch)...${RESET}"
docker run --rm -it -d --net=host \
--cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
-v $(pwd)/etc:/etc/suricata -v $(pwd)/lib:/var/lib/suricata -v $(pwd)/log:/var/log/suricata \
--name=suricata jasonish/suricata:latest-amd64 -i "$1" &> "$VERBOSE"

echo -e "${RED_BOLD}Fixing SIP, MQTT and RDP warnings.\n\
Creating rules file /etc/suricata/ctf.rules${RESET}"
touch /suricata/etc/ctf.rules &> "$VERBOSE"

python3 -c 'import re
FILE_PATH = "/suricata/etc/suricata.yaml"
SIP_FIX = r"sip:\n      #enabled: no"
MQTT_FIX = r"mqtt:\n      # enabled: no"
RDP_FIX = r"rdp:\n      #enabled: yes"
ADD_RULES = r"rule-files:\n  - suricata.rules"
with open(FILE_PATH, "r") as real_file:
    content = "".join(real_file.readlines())
    content = re.sub(SIP_FIX, "sip:\n      enabled: no", content)
    content = re.sub(MQTT_FIX, "mqtt:\n      enabled: no", content)
    content = re.sub(RDP_FIX, "rdp:\n      enabled: no", content)
    content = re.sub(ADD_RULES, ADD_RULES + "\n  - /etc/suricata/ctf.rules", content)
with open(FILE_PATH, "w") as modified_file:
	modified_file.write(content)' &> "$VERBOSE"

echo -e "${RED_BOLD}Updating Suricata${RESET}"
docker exec -it --user suricata suricata suricata-update -f &> "$VERBOSE"

echo -e "${RED_BOLD}Re-attaching back to Suricata's container${RESET}"
docker attach suricata
