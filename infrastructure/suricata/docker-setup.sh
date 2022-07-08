#!/bin/bash

function help() {
    echo -e "Usage:
    $(basename $0) < -d, --directory > ${UNDERLINED}directory${RESET} [ -l, --list_interfaces ] [ -v, --verbose ] [ -h, --help ] ${UNDERLINED}network_interface${RESET}"
    
    exit 0
}

function list_interfaces() {
    echo -e "${RED_BOLD}Your Network Interfaces are:${RESET}"
    
    for ((i = 1; i <= ${#network_interfaces[@]}; i++));
    do
        echo -e "${GREEN_BOLD}$i. ${BG_RED_FG_WHITE}${network_interfaces[i-1]}${RESET}"
    done
    
    exit 0
}

function banner() {
	DOCKER="${BG_WHITE_FG_BLUE}                        ##         .               ${RESET}
${BG_WHITE_FG_BLUE}                  ## ## ##        ==               ${RESET}
${BG_WHITE_FG_BLUE}               ## ## ## ## ##    ===               ${RESET}
${BG_WHITE_FG_BLUE}           /\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\\___/ ===             ${RESET}             
${BG_WHITE_FG_BLUE}      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~      ${RESET}
${BG_WHITE_FG_BLUE}           \\______ o           __/                 ${RESET}
${BG_WHITE_FG_BLUE}             \\    \\         __/                    ${RESET}
${BG_WHITE_FG_BLUE}              \\____\\_______/                       ${RESET}
${BG_WHITE_FG_BLUE}                                                   ${RESET}       
${BG_WHITE_FG_BLUE}              |          |                         ${RESET}
${BG_WHITE_FG_BLUE}           __ |  __   __ | _  __   _               ${RESET}
${BG_WHITE_FG_BLUE}          /  \\| /  \\ /   |/  / _\\ |                ${RESET}
${BG_WHITE_FG_BLUE}          \\__/| \\__/ \\__ |\\_ \\__  |                ${RESET}"

	SURICATA="${BG_BROWN_FG_YELLOW_BOLD}            __.              ,                     ${RESET}
${BG_BROWN_FG_YELLOW_BOLD}           (__ . .._.* _. _.-+- _.                 ${RESET}
${BG_BROWN_FG_YELLOW_BOLD}           .__)(_|[  |(_.(_] | (_]      by R1D3R175${RESET}"

	echo -e "${DOCKER}"
	echo -e "${SURICATA}"
}

RESET="\e[0m"
UNDERLINED="\e[4m"
RED_BOLD="\e[1;31m"
GREEN="\e[32m"
GREEN_BOLD="\e[1;32m"
BG_RED_FG_WHITE="\e[41;1;37m"
BG_WHITE_FG_BLUE="\e[44;1;37m"
BG_BROWN_FG_YELLOW_BOLD="\e[48;5;130m\e[38;5;220m\e[1m"

SHORT=d:,l,v,h
LONG=directory:,list_interfaces,verbose,help
OPTS=$(getopt --name suricata-docker-setup --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

VERBOSE="/dev/null"
INSTALL_DIR=""

banner

while :
do
    case "$1" in
        -d | --directory )
            INSTALL_DIR="$2"
            shift 2
        ;;
        -l | --list_interfaces )
            list_interfaces
        ;;
        -v | --verbose )
            VERBOSE="/dev/stdout"
            shift
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

if [ -z "$INSTALL_DIR" ];
then
    echo -e "${RED_BOLD}You must pass the installation directory!${RESET}"
    help
fi

INSTALL_DIR=$(realpath $INSTALL_DIR)

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

echo -e "${RED_BOLD}Creating ${INSTALL_DIR}/ ${RESET}"
mkdir -p "${INSTALL_DIR}/" &> "$VERBOSE"

if [ ! -d "${INSTALL_DIR}/" ];
then
    echo -e "${RED_BOLD}Failed to create ${INSTALL_DIR}/${RESET}"
    exit 0
fi

echo -e "${RED_BOLD}Creating sub-directories for Docker Volumes: ${RESET}\n\
	${GREEN}- ${INSTALL_DIR}/etc/${RESET}\n\
	${GREEN}- ${INSTALL_DIR}/lib/${RESET}\n\
	${GREEN}- ${INSTALL_DIR}/log/${RESET}"
mkdir {"${INSTALL_DIR}/etc/","${INSTALL_DIR}/lib/","${INSTALL_DIR}/log/"} &> "$VERBOSE"

echo -e "${RED_BOLD}Running Suricata container with interface $1${RESET}"
docker run --rm -it -d --net=host \
--cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
-v "${INSTALL_DIR}/etc":/etc/suricata -v "${INSTALL_DIR}/lib":/var/lib/suricata -v "${INSTALL_DIR}/log":/var/log/suricata \
--name=suricata jasonish/suricata:latest-amd64 -i "$1" &> "$VERBOSE"

echo -e "${RED_BOLD}Fixing SIP, MQTT and RDP warnings.${RESET}"
echo -e "${RED_BOLD}Creating rules file ${INSTALL_DIR}/etc/ctf.rules
and adding it to rules-file in ${INSTALL_DIR}/etc/suricata.yaml${RESET}"
touch "${INSTALL_DIR}/etc/ctf.rules" &> "$VERBOSE"

PYTHON_FIX='import re

FILE_PATH = "'${INSTALL_DIR}'/etc/suricata.yaml"
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
	modified_file.write(content)'

python3 -c "${PYTHON_FIX}" &> "$VERBOSE"

echo -e "${RED_BOLD}Running suricata-update${RESET}"
docker exec -it --user suricata suricata suricata-update -f &> "$VERBOSE"
echo -e "${RED_BOLD}Running suricatasc -c reload-rules${RESET}"

echo -e "${RED_BOLD}Re-attaching back to Suricata's container${RESET}"
docker attach suricata
