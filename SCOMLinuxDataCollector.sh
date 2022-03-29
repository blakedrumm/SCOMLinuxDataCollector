#! /bin/bash
#About:
#   This script is written for data collection from Linux machines which can help in troubleshooting SCOM UNIX/LINUX Agent (SCXAgent)
#Original Author :
#   Udish Mudiar, Microsoft Customer Service Support Professional
#Modified by :
#   Blake Drumm, Microsoft Customer Service Support Professional
#Feedback :
#   Email udmudiar@microsoft.com
#   Or the engineer you are working with


help()
{
    printf "\nAbout:\n\tThis shell script is used to collect basic information about the Operating System and SCOM Linux (SCX) Agent"
    printf "\n\tThis is a read -r only script and does not make any changes to the system."
    printf "\n\nUsage: [OPTIONS]"
    printf "\n  Options:"
    printf "\n    -o  OutputPath : Specify the location where the data would be collected. If not specified the script will collect the data in the current working directory."
    printf "\n\n    -m  SCXMaintenanceAccount : Specify the SCX Maintenance Account. This will be used to check the sudo privilege for the account."
    printf "\n\n    -n  SCXMonitoringAccount : Specify the SCX Monitoring Account. This will be used to check the sudo privilege for the account.\n"
}

check_distro(){
    printf "Checking distro. The script will proceed only for supported distro.....\n"
    printf "Checking distro. The script will proceed only for supported distro.....\n" >> "${path}"/scxdatacollector.log
    if [ "$(uname)" = 'Linux' ]; then
        printf "\tDistro is Linux. Continuing.....\n"
        printf "\tDistro is Linux. Continuing.....\n" >> "${path}"/scxdatacollector.log
    #elif [ condition ]; then
         # else if body
    else
        printf "\tDistro is not Linux (Detected: %s). Exiting.....\n" "$(uname)"
        printf "\tDistro is not Linux (Detected: %s). Exiting.....\n" "$(uname)" >> "${path}"/scxdatacollector.log
        exit
    fi
}

check_parameters(){
    #checking the number of parameters passed
    #we expect either 1 or 2 parameters which are the SCOM maintenance and monitoring account
    #if the parameters passed are greater than 2 then it is advised that you recheck the SCOM Run As Account and Profiles for streamlining your configuration.
    #you can refer to he below blog:
    # https://udishtech.com/how-to-configure-sudoers-file-for-scom-monitoring/
    if [ $# == 1 ]; then
        printf "The argument for sudo is: $1.....\n"
        printf "The argument for sudo is: $1.....\n" >> "${path}"/scxdatacollector.log
        create_dir "${path}/SCOMLinuxDataCollectorData/sudo"
        check_sudo_permission "$1"
    elif [ $# == 2 ]; then
        printf "The arguments for sudo are : $1 and $2.....\n"
        printf "The arguments for sudo are : $1 and $2.....\n" >> "${path}"/scxdatacollector.log
        create_dir "${path}/SCOMLinuxDataCollectorData/sudo"
        check_sudo_permission "$1" "$2"
    elif [ -z "${maint}" ] && [ -z "${mon}" ]; then
        printf "No SCOM Maintenance and Monitoring Account passed. Not collecting sudo details for the users....\n"
        printf "No SCOM Maintenance and Monitoring Account passed. Not collecting sudo details for the users....\n" >> "${path}"/scxdatacollector.log
        read -r -p 'Do you want to stop the script and rerun with the SCOM Accounts (Y/N)? ' response
       if [[ "${response}" == "Y" ]]; then
           printf "Exiting script....\n"
           exit 3
       elif [[ "${response}" == "N" ]]; then
            printf "Continuing script. But not collecting sudo details for the users....\n"
            printf "Continuing script. But not collecting sudo details for the users....\n" >> "${path}"/scxdatacollector.log
       fi
    fi
}

check_dir() {
    pwd=$(pwd)
    printf "Logs will be created in the output directory i.e. %s .....\n" "${path}"
    printf "Logs will be created in the output directory i.e. %s .....\n" "${path}" >> "${path}"/scxdatacollector.log
    printf "Creating the directory strucuture to store the data from the collector.....\n"
    printf "Creating the directory strucuture to store the data from the collector.....\n" >> "${path}"/scxdatacollector.log

    if [ -d "${path}/SCOMLinuxDataCollectorData" ]; then
        printf "\t Path %s/SCOMLinuxDataCollectorData is present. Removing and recreating the directory.....\n" "${path}"
        printf "\t Path %s/SCOMLinuxDataCollectorData is present. Removing and recreating the directory.....\n" "${path}" >> "${path}"/scxdatacollector.log
        rm -rf "${path}"/SCOMLinuxDataCollectorData
        create_dir "${path}/SCOMLinuxDataCollectorData"
    else
        printf "\t Path ${pwd} is not present in the current working directory. Creating the directory.....\n"
        printf "\t Path ${pwd} is not present in the current working directory. Creating the directory.....\n" >> "${path}"/scxdatacollector.log
        create_dir "${path}/SCOMLinuxDataCollectorData"
    fi

    create_dir "${path}/SCOMLinuxDataCollectorData/logs"
    create_dir "${path}/SCOMLinuxDataCollectorData/certs"
    create_dir "${path}/SCOMLinuxDataCollectorData/network"
    create_dir "${path}/SCOMLinuxDataCollectorData/scxdirectorystructure"
    create_dir "${path}/SCOMLinuxDataCollectorData/pam"
    create_dir "${path}/SCOMLinuxDataCollectorData/scxprovider"
    create_dir "${path}/SCOMLinuxDataCollectorData/configfiles"
}

create_dir(){
    if [ -d "$1" ]; then
        printf "\t Path $1 exists. No action needed......\n"
        printf "\t Path $1 exists. No action needed......\n" >> "${path}"/scxdatacollector.log
    else
        printf "\t Path $1 does not exists. Proceed with creation.....\n"
        printf "\t Path $1 does not exists. Proceed with creation.....\n" >> "${path}"/scxdatacollector.log
        mkdir -p "$1"
    fi
}

collect_os_details() {
    printf "Collecting OS Details.....\n"
    printf "\nCollecting OS Details.....\n" >> "${path}"/scxdatacollector.log
    collect_host_name
    collect_os_version
    collect_compute
    collect_disk_space
    collect_network_details
    collect_openssl_details
    collect_openssh_details sudo
    collect_crypto_details
    check_kerberos_enabled
    collect_selinux_details
}

collect_host_name() {
    printf "\tCollecting HostName Details.....\n"
    printf "\tCollecting Hostname Details.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******HOSTNAME******"  > "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    hostname >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    #below is what SCOM check while creating the self-signed certificate as CN
    printf "\n******HOSTNAME FOR CERTS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    nslookuphostname=$(nslookup "$(hostname)" | grep '^Name:' | awk '{print $2}' | grep "$(hostname)")
    if [ "${nslookuphostname}" ]; then
        printf "${nslookuphostname}" >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    else
        printf "Unable to resolve hostname from nslookup....." >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    fi
}

collect_os_version(){
    printf "\tCollecting OS Details.....\n"
    printf "\tCollecting OS Details.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******OS VERSION******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
	releasedata=$(cat /etc/*release)
	releaseversion=$(printf "$releasedata" | grep -Po '(?<=PRETTY_NAME=")[^"]*')
	printf "\t  Detected: ${releaseversion}"
    printf "$releasedata" >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
}

collect_compute(){
    printf "\n\tCollecting Memory and CPU for omi processes.....\n"
    printf "\tCollecting Memory and CPU for omi processes.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******MEM AND CPU FOR OMISERVER PROCESS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    ps -C omiserver -o %cpu,%mem,cmd >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******MEM AND CPU FOR OMIENGINE PROCESS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    ps -C omiengine -o %cpu,%mem,cmd >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******MEM AND CPU FOR OMIAGENT PROCESSES******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    ps -C omiagent -o %cpu,%mem,cmd >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
}

collect_openssl_details() {
    printf "\tCollecting Openssl & Openssh Details.....\n"
    printf "\tCollecting Openssl & Openssh Details.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******OPENSSL & OPENSSH VERSION******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    ssh -V  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt  2>&1
}

collect_openssh_details(){
    printf "\tCollecting SSH Details.....\n"
    printf "\tCollecting SSH Details.....\n" >> "${path}"/scxdatacollector.log
    #checking Kex settings in sshd. We are interested in the sshd server settings.
    printf "\n******SSH DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******KEY EXCHANGE ALGORITHIM (KEX) DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    $1 sshd -T | grep -E ^kexalgorithms >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******CIPHERS DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    $1 sshd -T | grep ciphers>> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******MACS DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    $1 sshd -T | grep macs >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    printf "\n******HOST KEY ALGORITHIMS DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    $1 sshd -T | grep keyalgorithms >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
	#copy the sshd configuration file
    echo -e "\n******Copying sshd config file******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    $1 cp -f /etc/ssh/sshd_config  "${path}"/SCOMLinuxDataCollectorData/configfiles/sshd_config_copy
}

collect_disk_space(){
    printf "\tCollecting the file system usage.....\n"
    printf "\tCollecting the file system usage.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******FILE SYSTEM DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    df -h >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
}

check_kerberos_enabled(){
    #This is not a full proof method as there are 3rd party tools who uses different ways to enable Kerb auth. Need more testing.
    printf "\tChecking if Kerberos Authentication is enabled. This might not be 100%% accurate....\n"
    printf "\tChecking if Kerberos Authentication is enabled. This might not be 100%% accurate....\n" >> "${path}"/scxdatacollector.log
    if [ -f "/etc/krb5.conf" ]; then
        isKerb=$(cat /etc/krb5.conf | grep -E "^default_realm" | wc -l)
        if [ "${isKerb}" = 1 ]; then
            printf "\t  Kerberos Authentication is enabled. This might not be 100%% accurate....\n"
            printf "\t  Kerberos Authentication is enabled. This might not be 100%% accurate....\n" >> "${path}"/scxdatacollector.log
        else
            printf "\t  Kerberos Authentication is not enabled. This might not be 100%% accurate....\n"
            printf "\t  Kerberos Authentication is not enabled. This might not be 100%% accurate....\n" >> "${path}"/scxdatacollector.log
        fi
    else
        printf "\t  Kerberos Authentication is not enabled. This might not be 100%% accurate....\n"
        printf "\t  Kerberos Authentication is not enabled. This might not be 100%% accurate....\n" >> "${path}"/scxdatacollector.log
    fi
}

collect_network_details(){
    printf "\tCollecting the network details.....\n"
    printf "\tCollecting the network details.....\n" >> "${path}"/scxdatacollector.log
    printf "\n******IP ADDRESS DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/network/ipdetails
    ip addr show >> "${path}"/SCOMLinuxDataCollectorData/network/ipdetails
    printf "\n******NETSTAT DETAILS******"  >> "${path}"/SCOMLinuxDataCollectorData/network/ipdetails
    #netstat is a deprecated utility.
    #netstat -anp >> ${path}/SCOMLinuxDataCollectorData/network/netstatdetails
    ss >> "${path}"/SCOMLinuxDataCollectorData/network/netstatdetails
}

check_sudo_permission(){
    account_1=$(/bin/echo "$1")
    account_2=$(/bin/echo "$2")
   if (( $# == 1 )); then
        printf "Checking the sudo permissions for the account ${account_1}...\n"
        printf "Checking the sudo permissions for the account ${account_1}.....\n" >> "${path}"/scxdatacollector.log
        create_dir "${path}/SCOMLinuxDataCollectorData/sudo"
        printf "******SUDO DETAILS FOR ${account_1}*****\n" > "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_1}"
        sudo -l -U "${account_1}" >> "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_1}"
   elif (( $# == 2 )); then
        printf "Checking the sudo permissions for the account ${account_1} and ${account_2}...\n"
        printf "Checking the sudo permissions for the account ${account_1} and ${account_2}...\n" >> "${path}"/scxdatacollector.log
        create_dir "${path}/SCOMLinuxDataCollectorData/sudo"
        printf "******SUDO DETAILS FOR %s*****\n" "${account_1}" > "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_1}"
        sudo -l -U "${account_1}" >> "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_1}"
        printf "******SUDO DETAILS FOR %s*****\n" "${account_2}" > "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_2}"
        sudo -l -U "${account_2}" >> "${path}"/SCOMLinuxDataCollectorData/sudo/"${account_2}"
   fi
}

collect_crypto_details(){
    printf "\tCollecting Crypto details.....\n"
    printf "\tCollecting Crypto details.....\n" >> "${path}"/scxdatacollector.log
    if [ "$(which update-crypto-policie 2>/dev/null)" ]; then
        printf "\t\t Crypto binary found. Collecting the status....\n" >> "${path}"/scxdatacollector.log
        printf "*****CRYPTO SETTINGS******\n" >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
        update-crypto-policies --show >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    else
        printf "\t\t Crypto binary not found....\n" >> "${path}"/scxdatacollector.log
    fi
}

collect_selinux_details(){
    printf "\tCollecting SELinux details.....\n"
    printf "\tCollecting SELinux details.....\n" >> "${path}"/scxdatacollector.log
    if [ "$(which sestatus 2>/dev/null)" ]; then
        printf "\t\t SELinux is installed. Collecting the status....\n" >> "${path}"/scxdatacollector.log
        printf "\n*****SELinux SETTINGS******\n" >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
        sestatus >> "${path}"/SCOMLinuxDataCollectorData/OSDetails.txt
    else
        printf "\t\t SELinux is not installed....\n" >> "${path}"/scxdatacollector.log
    fi
}

detect_installer(){
    # If DPKG lives here, assume we use that. Otherwise we use RPM.
    printf "Checking installer should be rpm or dpkg.....\n" >> "${path}"/scxdatacollector.log
    type dpkg > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        installer=dpkg
        printf "\tFound dpkg installer....\n" >> "${path}"/scxdatacollector.log
        check_scx_installed $installer "$1"
    else
        installer=rpm
        printf "\tFound rpm installer......\n" >> "${path}"/scxdatacollector.log
        check_scx_installed $installer "$1"
    fi
}

check_scx_installed(){
    printf "Checking if SCX is installed.....\n"
    printf "Checking if SCX is installed.....\n" >> "${path}"/scxdatacollector.log
    #we will check if the installer is rpm or dpkg and based on that run the package command.
    if [ "$installer" = "rpm" ]; then
        scx=$(rpm -qa scx 2>/dev/null)
        if [ "$scx" ]; then
            printf "\t SCX package is installed. Collecting SCX details.....\n"
            printf "\t SCX package is installed. Collecting SCX details.....\n" >> "${path}"/scxdatacollector.log
            #calling function to gather more information about SCX
            collect_scx_details "$2"
        else
            printf "SCX package is not installed. Not collecting any further details.....\n" >> "${path}"/scxdatacollector.log
        fi
    #we will assume if not rpm then dpkg.
    else
        scx=$(dpkg -s scx 2>/dev/null)
        if [ "$scx" ]; then
            printf "\t SCX package is installed. Collecting SCX details.....\n"
            printf "\t SCX package is installed. Collecting SCX details.....\n" >> "${path}"/scxdatacollector.log
            #calling function to gather more information about SCX
            collect_scx_details "$2"
        else
            printf "SCX package is not installed. Not collecting any further details.....\n" >> "${path}"/scxdatacollector.log
        fi
    fi


}

collect_scx_details(){
    scxversion=$(scxadmin -version)
    scxstatus=$(scxadmin -status)
    #netstat is a deprecated utility
    #netstat=`netstat -anp | grep :1270`
    netstat=$(ss -lp | grep -E ":opsmgr|:1270")
    omiprocesses=$(ps -ef | grep [o]mi | grep -v grep)
    omidstatus=$(systemctl status omid)
    printf "*****SCX VERSION******\n" > "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "${scxversion}\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "*****SCX STATUS******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "${scxstatus}\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "*****SCX PORT STATUS******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "${netstat}\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "*****OMI PROCESSES******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "${omiprocesses}\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "*****OMID STATUS******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "${omidstatus}\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt

    #unable to figure out the redirection for now
    #if the omiserver is stopped then we need to check the status by running the utility
    #omiserverstatus=`/opt/omi/bin/omiserver`
    #printf "omiserver status:\n $omiserverstatus\n" >> ${path}/scxdatacollector.log

    collect_scx_config_files
    collect_omi_scx_logs
    collect_omi_scx_certs
    collect_scx_directories_structure "$1"
    collect_omi_pam
    collect_scx_provider_status
    check_omi_core_files
    check_scx_omi_log_rotation
}

collect_scx_config_files(){
    printf "\t Copying config files.....\n"
    printf "\t Copying config files.....\n" >> "${path}"/scxdatacollector.log
    cp -f /etc/opt/omi/conf/omiserver.conf "${path}"/SCOMLinuxDataCollectorData/configfiles/omiserver.conf_copy
}

collect_omi_scx_logs(){
    printf "\t Collecting details of OMI and SCX logs.....\n"
    printf "\t Collecting details of OMI and SCX logs.....\n" >> "${path}"/scxdatacollector.log
    omilogsetting=$(cat /etc/opt/omi/conf/omiserver.conf | grep -i loglevel)
    printf "*****OMI LOG SETTINGS******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "$omilogsetting \n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    scxlogsetting=$(scxadmin -log-list)
    printf "*****SCX LOG SETTINGS******\n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt
    printf "$scxlogsetting \n" >> "${path}"/SCOMLinuxDataCollectorData/SCXDetails.txt

    printf "\t Copying OMI and SCX logs.....\n"
    printf "\t Copying OMI and SCX logs.....\n" >> "${path}"/scxdatacollector.log
    count1=$(ls -1 /var/opt/omi/log/*.log  2>/dev/null | wc -l)
    if [ "${count1}" != 0 ]; then
      printf "\t\t Found .log files in path /var/opt/omi/log. Copying the logs.. \n" >> "${path}"/scxdatacollector.log
      cp -f /var/opt/omi/log/*.log "${path}"/SCOMLinuxDataCollectorData/logs
    else
      printf "\t\t No .log files found in path /var/opt/omi/log. No action needed....\n" >> "${path}"/scxdatacollector.log
    fi

    count2=$(ls -1 /var/opt/omi/log/*.trc  2>/dev/null | wc -l)
    if [ "${count2}" != 0 ]; then
        printf "\t\t Found .trc files in path /var/opt/omi/log. Copying the logs.. \n" >> "${path}"/scxdatacollector.log
        cp -f /var/opt/omi/log/*.trc "${path}"/SCOMLinuxDataCollectorData/logs
    else
        printf "\t\t No .trc files found in path /var/opt/omi/log. No action needed.... \n" >> "${path}"/scxdatacollector.log
    fi

    count3=$(ls -1 /var/opt/microsoft/scx/log/*.log  2>/dev/null | wc -l)
    if [ "${count3}" != 0 ]; then
        printf "\t\t Found .log files in path /var/opt/microsoft/scx/log/*.log. Copying the logs.. \n" >> "${path}"/scxdatacollector.log
        cp -f /var/opt/microsoft/scx/log/*.log "${path}"/SCOMLinuxDataCollectorData/logs
    else
        printf "\t\t No .log files found in path /var/opt/microsoft/scx/log/*.log. No action needed.... \n" >> "${path}"/scxdatacollector.log
    fi
}

collect_omi_scx_certs(){
    printf "\t Collecting SCX cert details.....\n"
    printf "\t Collecting SCX cert details.....\n" >> "${path}"/scxdatacollector.log

    #checking omi certs
    if [ -d "/etc/opt/omi/ssl/" ]; then
      printf "\t \t Path /etc/opt/omi/ssl exists. Dumping details.....\n" >> "${path}"/scxdatacollector.log
      #dumping the list of files as the soft links can be broken at times of the permissions might be messed
      printf "\n******OMI CERTS STRUCTURE******\n" >> "${path}"/SCOMLinuxDataCollectorData/certs/certlist.txt
      ls -l /etc/opt/omi/ssl/ >> "${path}"/SCOMLinuxDataCollectorData/certs/certlist.txt

      cert=$(ls /etc/opt/omi/ssl/)
      omipubliccertsoftlink=$(find /etc/opt/omi/ssl | grep omi.pem)

      #checking the omi.pem
        if [ -f "${omipubliccertsoftlink}" ]; then
            printf "\t \t omi public cert exists.....\n" >> "${path}"/scxdatacollector.log
        else
            printf "\t \t omi public cert does not exists.....\n" >> "${path}"/scxdatacollector.log
        fi
    else
      printf "\t \t Path /etc/opt/omi/ssl does not exists.....\n" >> "${path}"/scxdatacollector.log
    fi

    #checking scx certs
    if [ -d "/etc/opt/microsoft/scx/ssl/" ]; then
        printf "\t \t Path /etc/opt/microsoft/scx/ssl/ exists. Dumping details.....\n" >> "${path}"/scxdatacollector.log
        printf "\n******SCX CERT STRUCTURE******\n" >> "${path}"/SCOMLinuxDataCollectorData/certs/certlist.txt
        ls -l /etc/opt/microsoft/scx/ssl/ >> "${path}"/SCOMLinuxDataCollectorData/certs/certlist.txt

        scxpubliccertsoftlink=$(find /etc/opt/microsoft/scx/ssl | grep scx.pem)
        #checking the scx.pem
        #dumping scx.pem as SCOM uses it.
        if [ -f "${scxpubliccertsoftlink}" ]; then
            printf "\t \t scx public cert exists..Dumping details.....\n" >> "${path}"/scxdatacollector.log
            openssl x509 -in /etc/opt/microsoft/scx/ssl/scx.pem -text > "${path}"/SCOMLinuxDataCollectorData/certs/certdetails_long.txt
            openssl x509 -noout -in /etc/opt/microsoft/scx/ssl/scx.pem  -subject -issuer -dates > "${path}"/SCOMLinuxDataCollectorData/certs/certdetails_short.txt
        else
            printf "\t \t scx public cert does not exists.....\n" >> "${path}"/scxdatacollector.log
        fi
    else
        printf "\t \t Path Path /etc/opt/microsoft/scx/ssl/ does not exists.....\n" >> "${path}"/scxdatacollector.log
    fi
}

collect_scx_directories_structure(){
    printf "\t Collecting SCX DirectoryStructure.....\n"
    printf "\t Collecting SCX DirectoryStructure.....\n" >> "${path}"/scxdatacollector.log
    $1 ls -lR /var/opt/microsoft/ >> "${path}"/SCOMLinuxDataCollectorData/scxdirectorystructure/var-opt-microsoft
    $1 ls -lR /var/opt/omi >> "${path}"/SCOMLinuxDataCollectorData/scxdirectorystructure/var-opt-omi
    $1 ls -lR /opt/omi/ >> "${path}"/SCOMLinuxDataCollectorData/scxdirectorystructure/opt-omi
    $1 ls -lR /etc/opt/microsoft/ >> "${path}"/SCOMLinuxDataCollectorData/scxdirectorystructure/etc-opt-microsoft
    $1 ls -lR /etc/opt/omi >> "${path}"/SCOMLinuxDataCollectorData/scxdirectorystructure/etc-opt-omi
}

collect_omi_pam(){
    printf "\t Collecting omi PAM details.....\n"
    printf "\t Collecting omi PAM details.....\n" >> "${path}"/scxdatacollector.log
    if [ -f /etc/opt/omi/conf/pam.conf ]; then
        # PAM configuration file found; use that
        cp /etc/opt/omi/conf/pam.conf "${path}"/SCOMLinuxDataCollectorData/pam/pam.conf
    elif [ -f /etc/pam.d/omi ]; then
        cp /etc/pam.d/omi "${path}"/SCOMLinuxDataCollectorData/pam/omi
    fi
}

collect_scx_provider_status(){
   printf "\t Collecting SCX Provider Details.....\n"
   printf "\t Collecting SCX Provider Detail.....\n" >> "${path}"/scxdatacollector.log
   if [ -d "/etc/opt/omi/conf/omiregister" ]; then
      printf "\t\t omiregister directory found. Collecting more details.....\n" >> "${path}"/scxdatacollector.log
      cp /etc/opt/omi/conf/omiregister/root-scx/* "${path}"/SCOMLinuxDataCollectorData/scxprovider
   else
      printf "\t\t omiregister directory not found......\n" >> "${path}"/scxdatacollector.log
   fi

   printf "\t\t Query the omi cli and dumping details for one class from each identity (root, req, omi).....\n" >> "${path}"/scxdatacollector.log
   #We cam think of dumping all the class information if required.
   #However, we need to keep in mind if the provider is hung then we can to kill the query after sometime. That logic has to be built later.
   /opt/omi/bin/omicli ei root/scx SCX_UnixProcess >> "${path}"/SCOMLinuxDataCollectorData/scxprovider/scxproviderstatus
   /opt/omi/bin/omicli ei root/scx SCX_Agent >> "${path}"/SCOMLinuxDataCollectorData/scxprovider/scxproviderstatus
   /opt/omi/bin/omicli ei root/scx SCX_OperatingSystem >> "${path}"/SCOMLinuxDataCollectorData/scxprovider/scxproviderstatus
}

check_omi_core_files(){
   printf "\t Check for core files in SCX directory /var/opt/omi/run/.....\n"
   printf "\t Check for core files in SCX directory /var/opt/omi/run/......\n" >> "${path}"/scxdatacollector.log

   corefilescount=$(ls -1 /var/opt/omi/run/core* 2>/dev/null | wc -l)
    if [ "${corefilescount}" != 0 ]; then
      printf "\t\t Found core files in path /var/opt/omi/run/. Copying the core files.. \n" >> "${path}"/scxdatacollector.log
      cp -f /var/opt/omi/run/core* "${path}"/SCOMLinuxDataCollectorData/logs
    else
      printf "\t\t No core files found in path /var/opt/omi/run/. No action needed....\n" >> "${path}"/scxdatacollector.log
    fi

}

check_scx_omi_log_rotation(){
    printf "\t Checking the log rotation configuration for omi and scx.....\n"
    printf "\t Checking the log rotation configuration for omi and scx......\n" >> "${path}"/scxdatacollector.log
    if [ -f "/etc/opt/omi/conf/omilogrotate.conf" ]; then
        printf "\t Found omilogrotate.conf in path /etc/opt/omi/conf. Copying the file.. \n" >> "${path}"/scxdatacollector.log
        cp -f /etc/opt/omi/conf/omilogrotate.conf  "${path}"/SCOMLinuxDataCollectorData/configfiles/omilogrotate.conf_copy
    else
        printf "\t Not found omilogrotate.conf in path /etc/opt/omi/conf...... \n" >> "${path}"/scxdatacollector.log
    fi
    if [ -f "/etc/opt/microsoft/scx/conf/logrotate.conf" ]; then
        printf "\t Found logrotate.conf in path /etc/opt/microsoft/scx/conf. Copying the file.. \n" >> "${path}"/scxdatacollector.log
        cp -f /etc/opt/microsoft/scx/conf/logrotate.conf  "${path}"/SCOMLinuxDataCollectorData/configfiles/scxlogrotate.conf_copy
    else
        printf "\t Not found omilogrotate.conf in path /etc/opt/microsoft/scx/conf. Copying the file.. \n" >> "${path}"/scxdatacollector.log
    fi 
}

archive_logs () {
   printf "\nSuccessfully completed the SCOM Linux Data Collector.....\n" >> "${path}"/scxdatacollector.log
   if [ -f "${path}/SCOMLinuxDataCollectorData.tar.gz" ]; then
      printf "\nFile SCOMLinuxDataCollectorData.tar.gz already exist. Cleaning up before new archive.....\n"
      printf "\nFile SCOMLinuxDataCollectorData.tar.gz already exist. Cleaning up before new archive.....\n"  >> "${path}"/scxdatacollector.log
      rm -rf "${path}"/SCOMLinuxDataCollectorData.tar.gz

   fi
   printf "Moving the scxdatacollector.log file to SCOMLinuxDataCollectorData.\n"
   printf "Moving the scxdatacollector.log file to SCOMLinuxDataCollectorData. Archiving and zipping SCOMLinuxDataCollectorData. Clean up other data....\n" >> "${path}"/scxdatacollector.log
   echo -e "\n $(date) Successfully completed the SCOM Linux Data Collector steps. Few steps remaining....\n" >> "${path}"/scxdatacollector.log
   mv "${path}"/scxdatacollector.log "${path}"/SCOMLinuxDataCollectorData
   printf "Archiving and zipping SCOMLinuxDataCollectorData.\n"
   tar -cf "${path}"/SCOMLinuxDataCollectorData.tar "${path}"/SCOMLinuxDataCollectorData

   gzip "${path}"/SCOMLinuxDataCollectorData.tar
   printf "Clean up other data....\n"
   rm -rf "${path}"/SCOMLinuxDataCollectorData.tar
   rm -rf "${path}"/SCOMLinuxDataCollectorData
}

#this function fetches the maximum information
sub_main_root(){
    check_dir "$path"
    collect_os_details
	if [ ! -n "$maint" ] || [ ! -n "$mon" ]; then
		check_sudo_permission "$maint" "$mon"
	else
		check_sudo_permission "$(whoami)"
	fi
    detect_installer
    #This has to be the last function call in the script
    #archive_logs
}

#this function fetches the less information
sub_main_non_root(){
    check_dir "$path"
    collect_os_details
	if [ ! -n "$maint" ] || [ ! -n "$mon" ]; then
		check_sudo_permission "$maint" "$mon"
	else
		check_sudo_permission "$(whoami)"
	fi
    detect_installer sudo
    #This has to be the last function call in the script
    archive_logs
}

main(){
    printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    #clearing the scxdatacollector.log file to start with
    #using sudo out-of-box even if the user is root to avoid permission denied on the intial log file creation.
    sudo printf "" > "${path}"/scxdatacollector.log
    

    if [ ! -n "${path}"  ]; then
        printf "Log Collection Path is NULL. Setting Path to current working directory......\n"
        printf "Log Collection Path is NULL. Setting Path to current working directory......\n" >> "${path}"/scxdatacollector.log
        path=$(pwd)
    fi

    #Currently supporting SCX 2016+ versions
    printf "Starting the SCOM Linux Data Collector.....\nDisclaimer: Currently supporting SCX 2016+ versions\n"
    printf "$(date)Starting the SCOM Linux Data Collector.....\n" > "${path}"/scxdatacollector.log
    printf "The arguments passed are: \n Path = ${path} \n Maint = ${maint} \n Mon = ${mon} \n"
    printf "The arguments passed are: \n Path = ${path} \n Maint = ${maint} \n Mon = ${mon} \n" >> "${path}"/scxdatacollector.log

    #checking the distro. Will only continue in supported distro
    check_distro

    #fetching the user under which the script is running.
    user="$(whoami)"
    printf "Script is running under user: ${user}.....\n"
    printf "Script is running under user: ${user}.....\n" >> "${path}"/scxdatacollector.log
    if [ "$user"=='root' ]; then
         printf "\t User is root. Collecting maximum information.....\n"
         sub_main_root "$path" "$maint" "$mon"
    else
         printf "\t User is non root. Collecting information based on the level of privilege.....\n"
         sub_main_non_root "$path" "$maint" "$mon"
    fi
}

############################################################
# Script execution starts from here.                       #
############################################################


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "ho:m:n:" option; do
   case $option in
      h) # display Help
         help
         exit;;
      o) # Enter log collection path
         path=$OPTARG
         ;;
      m) # Enter log collection path
         maint=$OPTARG
         ;;
      n) # Enter log collection path
         mon=$OPTARG
         ;;
     \?) # Invalid option
         printf "Error: Invalid option - Run help (-h) for full parameters"
         exit;;
   esac
done

#function calls
        main "$path" "$maint" "$mon"

printf "\nSuccessfully completed the SCOM Linux Data Collector.....\n"
printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
