#!/bin/bash

echo -e "\e[1;31mCreating /suricata... \e[0m"
mkdir /suricata 
cd /suricata

echo -e "\e[1;31mCreating sub-directories for Docker Volumes: \e[0m\n\
\e[;32m/suricata/etc/ \e[0m\n\
\e[;32m/suricata/lib/ \e[0m\n\
\e[;32m/suricata/log/ \e[0m"
mkdir {etc,lib,log}

echo -e "\e[1;31mRunning Suricata container (detatch)...\e[0m"
docker run --rm -it -d --net=host \
	 --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
	 -v $(pwd)/etc:/etc/suricata -v $(pwd)/lib:/var/lib/suricata -v $(pwd)/log:/var/log/suricata \
	 --name=suricata jasonish/suricata:latest-amd64 -i eth0

echo -e "\e[1;31mFixing SIP, MQTT and RDP warnings.\n\
Creating rules file /etc/suricata/ctf.rules\e[0m"
touch /suricata/etc/ctf.rules

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
    modified_file.write(content)'

echo -e "\e[1;31mUpdating Suricata\e[0m"
docker exec -it --user suricata suricata suricata-update -f

echo -e "\e[1;31mRe-attaching back to Suricata's container\e[0m"
docker attach suricata
