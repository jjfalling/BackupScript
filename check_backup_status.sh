#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#############################################################################
# check_backup_status.sh
#
# This checks for backup_script_status in /backup*/*/tmp/ and if it exists 
# checks the date inside the file.
# If the date is more then a day off then an email with the list of stale 
# backups is sent. This will also fail a backup if the date is in the future
#
#############################################################################
#
#
#****************************************************************************
#*   Copyright (C) 2013 by Jeremy Falling except where noted.               *
#*                                                                          *
#*   This program is free software: you can redistribute it and/or modify   *
#*   it under the terms of the GNU General Public License as published by   *
#*   the Free Software Foundation, either version 3 of the License, or      *
#*   (at your option) any later version.                                    *
#*                                                                          *
#*   This program is distributed in the hope that it will be useful,        *
#*   but WITHOUT ANY WARRANTY; without even the implied warranty of         *
#*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          *
#*   GNU General Public License for more details.                           *
#*                                                                          *
#*   You should have received a copy of the GNU General Public License      *
#*   along with this program.  If not, see <http://www.gnu.org/licenses/>.  *
#****************************************************************************

#############################################################################
#First, lets define a few of things

# ***CHANGE THE FOLLOWING***

#The email to address to send an email address to incase of failure
erroremailaddr="user@domain.tld"

#The hostname of this server
systemname="backup.domain.com"

#Where do we want the log to go?
logfile="/var/log/backup_status_check_log"

#############################################################################

#help/usage message
usage()
	{
	cat << usageEOF
	
	usage: $0 options
	Example usage: $0 [-n]
	
	This script checks the status of backups. 
	
	
	OPTIONS:
	-h      Show this message
	-n      Run as nrpe plugin

	
usageEOF
}
#end help 


#this sends the email alert when something goes wrong
function create_alert {

        echo "$error_message" | mail -s "Backup problem detected during verification on $systemname" "$erroremailaddr"

}

function nrpe_check {

	#see if the logfile is over 25hrs old
	fileAge=`find $logfile -mmin -1550 |wc -l |tr -d ' '`

	#check if the file is newer then 25hrs
	if [ "$fileAge" == 1 ]
	then

			#file is newer then 25hrs, check if things are ok
			status=`grep -q "Everything seems fine..." $logfile; echo $?`
			if [ "$status" == 0 ]
			then
					echo "Backups are ok"
					exit 0


			#things appear not to be ok
			else
					echo "Backups seem to be failing, please check $logfile"
					exit 2

			fi


	#file is older then 25hrs
	else
			echo "Backup checker has not ran in the last 25 hrs or file does not exist"
			exit 2

	fi

}


#getops stuff
while getopts “ht:n” OPTION
do
      case $OPTION in
          h)
              usage
              exit 1
              ;;
          n)
              nrpe_check
              ;;
          ?)
              usage
              exit 1
              ;;
      esac
done



#get date
#min_last_run=`date -v -1d +%Y%m%d`
min_last_run=`date --date="yesterday" +%Y%m%d`
max_last_run=`date +%Y%m%d`

#delete old log file, and create new one.
rm $logfile
touch $logfile


echo "Starting to check backup status" >> $logfile
date >> $logfile
echo "" >> $logfile


#create array of backup status files
dir_array=(`ls /*backup*/tmp/backup_script_status`)
num_of_dir=${#dir_array[*]}


#go through the array and check each status file
i=0
future="false"
final_result=""


while [ $i -lt $num_of_dir ]
do


                result=""
                last_check=""
                current_file="${dir_array[$i]}"
                current_val=`cat $current_file`


                if [ "$current_val" -ge "$min_last_run" ] && [ "$current_val" -le "$max_last_run" ]
                then

                result="pass"

        else


                result="fail"
                final_result="fail"

        fi


        if [ "$current_val" -gt "$max_last_run" ]
        then

                future="true"

        fi


        echo $current_file >> $logfile
        echo $current_val >> $logfile
        echo $result >> $logfile
        echo "" >> $logfile

        let i++

done


loginfo=`cat $logfile`


if [ "$final_result" == "fail" ] &&  [ "$future" == "false" ]
then

                error_message="It seems one or more servers have not backed up in the last 24 hours. Please see $logfile"
                create_alert

                echo "" >> $logfile
                echo "Alert sent due to one or more servers not backing up" >> $logfile


elif [ "$future" == "true" ]
then

                error_message="It seems one or more servers have not backed up in the last 24 hours and atleast one of them is reporting a date in the future. Please  see $logfile"
                create_alert
                echo "Alert sent due to one or more server not backing up and one of them reporting time in the future" >> $logfile

else

                echo "" >> $logfile
                echo "Everything seems fine..." >> $logfile

fi


exit 0