#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#######################################################
# check_backup_status.sh
#
# ***************************************************************************
# * Copyright (C) 2011 by Jeremy Falling except where noted. *
# * *
# * This program is free software; you can redistribute it and/or modify *
# * it under the terms of the GNU General Public License as published by *
# * the Free Software Foundation; either version 2 of the License, or *
# * (at your option) any later version. *
# * *
# * This program is distributed in the hope that it will be useful, *
# * but WITHOUT ANY WARRANTY; without even the implied warranty of *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the *
# * GNU General Public License for more details. *
# * *
# * You should have received a copy of the GNU General Public License *
# * along with this program; if not, write to the *
# * Free Software Foundation, Inc., *
# * 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *
# ***************************************************************************
#
# This checks for backup_script_status in /backup*/*/tmp/ and if it exists checks the date inside the file.
# If the date is more then a day off then an email with the list of stale backups is sent.
# This will also fail a backup if the date is in the future
#######################################################
#First, lets define a few of things#
####################################

# ***CHANGE THE FOLLOWING***

#The email to address to send an email address to incase of failure
erroremailaddr="user@domain.tld"

#The hostname
systemname="backup.jfalling.com"

#Where do we want the log to go?
logfile="/var/log/backup_status_check_log"

#######################################################
#get date
min_last_run=`date -v -1d +%Y%m%d`
max_last_run=`date +%Y%m%d`


#this sends the email alert when something goes wrong
function send_alert {
echo "$error_message" | mail -s "Backup problem detected during verification on $systemname" "$erroremailaddr"

}

#delete old log file, and create new one.
rm $logfile
touch $logfile

echo "Starting to check backup status" >> $logfile
date >> $logfile
echo "" >> $logfile

#create array of backup status files
dir_array=(`ls /backup*/*/tmp/backup_script_status`)
num_of_dir=${#dir_array[*]}

#go through the array and check each status file
i=0
future="false"
final_result=""

while [ $i -lt $num_of_dir ]; do

        result=""
        last_check=""

        current_file="${dir_array[$i]}"
        current_val=`cat $current_file`

        if [ "$current_val" -ge "$min_last_run" ] && [ "$current_val" -le "$max_last_run" ]; then
                result="pass"
        else
                result="fail"
                final_result="fail"
        fi

        if [ "$current_val" -gt "$max_last_run" ]; then
                future="true"
        fi

        echo $current_file >> $logfile
        echo $current_val >> $logfile
        echo $result >> $logfile
        echo "" >> $logfile

        let i++

done


loginfo=`cat $logfile`


if [ "$final_result" == "fail" ] &&  [ "$future" == "false" ]; then
        error_message="It seems one or more servers have not backed up in the last 24 hours. Please see $logfile"
        send_alert

        echo "" >> $logfile
        echo "Alert sent due to one or more servers not backing up" >> $logfile

elif [ "$future" == "true" ]; then
        error_message="It seems one or more servers have not backed up in the last 24 hours and atleast one of them is reporting a date in the future. Please  see $logfile"
        send_alert
        echo "Alert sent due to one or more server not backing up and one of them reporting time in the future" >> $logfile

else

        echo "" >> $logfile
        echo "Everything seems fine..." >> $logfile

fi

exit 0