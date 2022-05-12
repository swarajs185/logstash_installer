cat << EOT
=================================================================================================
LOGSTASH INSTALLER!!! 
dev:sswraj@
==================================================================================================
EOT
echo -e "INSTALLATION BEGINS NOW \n"
sudo cp logstash.repo /etc/yum.repos.d/
home=~/logstash-installer/logs
rm -f GPG-KEY-elasticsearch* #removing the old key files
if [ ! -d "$home/applog" ]; then #Creating the log folder for the first time
        mkdir -p $home/applog
fi
if [ ! -d "$home/apperror" ]; then #creating the error folder for the first name
        mkdir -p $home/apperror
fi
date_log=`date  | cut -d " " -f 4 | sed -e "s/:/_/g"`
logfile=$home/applog/logfile_$date_log.log
errorfile=$home/apperror/errorfile_$date_log.log
#echo $logfile
#echo $errorfile
repository=/etc/yum.repos.d/logstash.repo
echo "Log file: $logfile"
echo -e "Error file: $errorfile \n "

installingjava(){
    if [ -d "/usr/lib/java-1.8.0" ]; then
        echo -e "Java binaries are installing.. In case java is already installed. process will be ignored"
        sudo yum install java-1.8.0-openjdk.x86_64 -y >>$logfile 2>> $errorfile
        sleep 1
else
        echo -e "Installing java 1.8... \n"
        sudo yum install java-1.8.0-openjdk.x86_64 -y >> $logfile 2>> $errorfile
        if [ -s $errorfile ]; then
                echo -e "Installed successfully \n"
        else
                echo "Installation failed with errors:"
                echo "check the errorfile for more details on $errorfile"
                exit 1
        fi
fi
}
installingjava

installingsixversion(){
    checkversion
    ret=$?
    if [ $ret = 1 ] 
    then
        echo "Installing logstash 6.8 version"
        echo -e "Configuring and Installing Dependencies... \n"
        sudo wget https://artifacts.elastic.co/GPG-KEY-elasticsearch >> $logfile 2>> $errorfile
        sleep 1
        echo "Dependencies downloaded!! ...Searching for logstash repo"
        if [ -e $repository ]; then
        echo -e "Logstash repository found!!! \n"
        else
        echo -e "LOGSTASH Config file not found ........ Create a logstash.repo under /etc/yum.repos.d/ \n"
        sudo yum install logstash >> $errorfile 2>> $errorfile
        echo "check $errorfile for more details"
        exit 1
        fi
        echo -e "Installing Logstash \n "
        sudo yum install logstash -y >> $logfile 2>> $errorfile
        sudo usermod -a -G logstash ec2-user
        echo -e "Installing amazon-es plugin \n"
        sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-amazon_es >>$logfile 2>>$errorfile
        echo "Installation Complete.. Please create a pipeline on '/etc/logstash/logstash.conf' and run 'sudo /usr/share/logstash/bin/logstash -f /etc/logstash/logstash.conf'"
        exit 1
    else
       if [ $ret = 2 ] 
       then
           echo "You already have 6.8.23 version installed..."
        else
           echo "You already have latest version 7.16.3 version installed..."
       fi
    fi
}

installingsevenversion(){
    echo "Trying to install 7.16.3..."
    echo "Checking the previous versions on the EC2 instance..."
    checkversion
    ret=$?
    if [ $ret = 3 ] 
    then
        echo "You are already having the latest version: 7.16.3"
        exit 1
    elif [ $ret = 2 ]
    then
        echo "Current version: 6.8.23"
        echo "Would you like to upgrade to 7.16.3? [yes/no]:"
        read option
        if [ $option = "yes" ] 
        then
        echo "Deleting old version"
        sudo yum remove logstash -y >>$logfile 2>>$errorfile
        sudo rm -rf /etc/logstash
        sudo rm -rf /usr/share/logstash
        echo "Deletion of 6.8.3 completed, installing the new one"
        sevenversioninstall
        else
        echo "No action required"
        fi
    else
       echo "No Previous versions Found!!!"
       sevenversioninstall
    fi
}

sevenversioninstall(){
    echo "Installing the 7.16.3 version..."
    if [ ! -e ./logstash-oss-7.16.3-x86_64.rpm ] 
    then
    echo "Installing Artifacts"
    sudo wget https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.16.3-x86_64.rpm >>$logfile 2>>$errorfile
    fi
    echo "installing binaries"
    sudo rpm -ivh logstash-oss-7.16.3-x86_64.rpm >>$logfile 2>>$errorfile
    echo "Installing the logstash-output-opensearch plugin"
    sudo /usr/share/logstash/bin/logstash-plugin  install --preserve logstash-output-opensearch
    echo "Installed the plugin" >>$logfile
    echo "Installation Successful"
}

checkversion(){
    if [ -d /usr/share/logstash/bin ] 
    then
    if [ "`/usr/share/logstash/bin/logstash --version | cut -d " " -f 2 | sed -n '2p'`" = "7.16.3" ]
    then
        return 3

    elif [ "`/usr/share/logstash/bin/logstash --version | cut -d " " -f 2`" = "6.8.23" ] 
    then
        return 2
    fi

    else
        return 1
    fi
}


uninstalllogstash(){
    checkversion
    ret=$?
    if [ $ret = 2 ] 
    then
    echo "Uninstalling 6.8.23"
    sudo yum remove logstash -y >>$logfile 2>>$errorfile
    echo "cleaning up.."
    sudo rm -rf /etc/logstash
    sudo rm -rf /usr/share/logstash
    checkversion
    ret=$?
    if [ $ret = 1 ]
    then
    echo "Uninstallation complete.."    
    fi
    elif [ $ret = 3 ]  
    then
    echo "Uninstalling 7.16.3"
    sudo rpm -e logstash-oss-7.16.3-1.x86_64 >>$logfile 2>>$errorfile
    echo "cleaning up.."
    sudo rm -rf /etc/logstash
    sudo rm -rf /usr/share/logstash
    checkversion
    ret=$?
    if [ $ret = 1 ] 
    then
    echo "Uninstallation Complete..."
    fi
    else
    echo "Nothing to Uninstall.."   
    fi
}


cat << EOT
=================================================================================================
Please enter which version you would like to install!
1. 6.8.3
2. 7.16.3 (As a Service)
3. Uninstall Logstash
==================================================================================================
EOT
echo "Please Enter your choice [1/2/3]: "
read version

case $version in
        1) installingsixversion;;
        2) installingsevenversion;;
        3) uninstalllogstash;;
        *) echo default
        echo "Not Found will be updating the script soon..."
        ;;
esac