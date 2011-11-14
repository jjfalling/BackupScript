#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#############################################################################
# backup_script.sh                                     
# This is a script to do backups. It calls target_commands.sh
# It does a bit of checking to make sure nothing went wrong and shoots of an 
# email if somethings a bit off.
#
# REQUIREMENTS:
# mail, and hostname commands, as well as rsync and bash must be available. 
# Also on Fbsd add :/usr/local/bin to the end of the path in crontab.
#
#
# *****************************************************
# ****   DO NOT CHANGE *ANYTHING* IN THIS SCRIPT.  ****
# ****See target_commands.sh in the same directory!****
# *****************************************************
#
#
#############################################################################
#
#
# ***************************************************************************
# *   Copyright (C) 2011 by Jeremy Falling except where noted.              *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
# ***************************************************************************
#
#
# CHANGELOG 
#
# 1.0.0 
# 		*inital release
# 1.0.1
#		*rewrite the rsync check function so it wont fail on an exit code of 
#		 24 (Partial transfer due to vanished source files) and echos rsync 
#		 codes to the log file.
#		*change log path to a variable defined in user define section.
#		*change interpreter to /usr/bin/env bash and added path declaration 
#		 for portability.
#		*added support for checking mysql dumps/rotations (check 
#		 check_sqldump_mv).
#		*script tries to continue when part of the actual backup fails 
#		 (moving files, dumps, rsync, etc). originally it would cry a bit 
#		 and exit.
# 1.0.2
#		*include target_commands.sh in same directory. This contains functions
#		 which contain the backup commands. This is to make this script 
#		 cleaner and keep eliminates the need to touch this script.
#		*create last status file which has the date that this script last 
#		 ran. This will be in /tmp on each server and have its own line to 
#		 transfer the file to the backup server.
# 1.0.2
#		*added an option to not preform sql rotations or backups
#
#
#############################################################################
#Lets find our pwd
fullpath=$(cd ${0%/*} && echo $PWD/${0##*/})


#Get the path the script is in
script_dir=`dirname "$fullpath"`


#Include file that contains the backup commands. If the file does not exist then exit.
if [ -f $script_dir/target_commands.sh ]  
then

	source $script_dir/target_commands.sh

else

	echo "Cannot include target_commands.sh. I cannot continue until the target_commands.sh file exists in the same directory as me and I can include it!"
	echo "Exiting....."

exit 1

fi


##############################################################################
#host name for this machine, or you could do this manually.
# NOTE: old versions of hostname dont support -f (-f is full hostname with domain)

systemname=$(hostname -f)

#Initilize some variables

failure=0
failure_2=0
start_date=$(date)


#############################################################################
#Create some functions#
#######################


#This sends the email alert when something goes wrong
function send_alert {

	echo "$error_message" | mail -s "Backup problem on $systemname" "$erroremailaddr"

}


#***************************************************************************#


#this checks to see if each rsync instance runs correctly
# and puts the exit status in the log
function check_rsync {

	status=$?
	echo "Rsync exit status is: $status" >> $backup_logfile
	echo "" >> $backup_logfile
	echo "" >> $backup_logfile

	if [ "$status" != "0" ] && [ "$status" != "24" ]; then

		failure="1"

	fi
}


#***************************************************************************#


#this checks to see if each sql dump/mv instance runs correctly
function check_sqldump_mv {

	status_2=$?
	echo "Command exit status is: $status" >> $backup_logfile
	echo "" >> $backup_logfile
	echo "" >> $backup_logfile

	if [ "$status_2" != "0" ]; then

		failure_2="1"

	fi
}


#############################################################################


#Prep work done, we attempt to start the backup. First Lets check to see if 
# this script is already running


#The small segment below is adapted from 
# http://www.askdavetaylor.com/shell_script_test_to_see_if_its_already_running.html

if [ -f /tmp/backup_script.lock ]
then

	#the lock file already exists, so check to see if the pid is valid
	
	if [ "$(ps -p `cat /tmp/backup_script.lock` | wc -l)" -gt 1 ]
	then

		#the another backup is running, send an alert and bail!
		echo "$0: quit at start: lingering process `cat /tmp/backup_script.lock`"
		error_message="ERROR the backup script on $systemname is already running and I cannot run another copy!.... BACKUP HAS FAILED!"
		send_alert
		exit 1

	else

		#process not running, but lock file not deleted? lets log it, delete the lock, and continue
		#remove old log and create new one.
		rm $backup_logfile
		touch $backup_logfile
		echo " $0: orphan lock file warning. Lock file deleted." >> $backup_logfile
		rm /tmp/backup_script.lock

	fi

else

	#Lock file does not exits so lets remove the old log and create new one
	rm $backup_logfile
	touch $backup_logfile

fi


#create lock file
echo $$ > /tmp/backup_script.lock


#rm and re-create last_run file. This is used for server side checking.
rm /tmp/backup_script_status
touch /tmp/backup_script_status
date "+%Y%m%d" > /tmp/backup_script_status

echo started: $start_date >> $backup_logfile


#check to see if hostname includes domain
echo $systemname | grep $domainname


if [ "$?" != "0" ] 
then
	systemname="$systemname.$domainname"

fi


#do we want to run a sql backup rotation
if [ "$run_sqlrotation" = "yes" ]
then

	#since the script has made it this far, time to start the backup
	#call the run_sql_backup_rotation function from target_commands.sh
	run_sql_backup_rotation


#was there a problem with the last group of commands?
if [ "$failure_2" != "0" ]
then

	echo FILE MOVE PROBLEM!
	error_message="ERROR problem with rotating sql dumps on $systemname. BACKUP HAS possibly FAILED! See $backup_logfile"
	send_alert
	
	#reset failure_2 for next if statement
	failure_2=0

fi

else

	echo "Sql rotation skipped per config" >> $backup_logfile
	echo "" >> $backup_logfile

fi


#do we want to run a sql backup
if [ "$run_sqlbackup" = "yes" ]
then

	#call the run_sql_backup_dump function from target_commands.sh
	run_sql_backup_dump

	#was there a problem with the last group of commands?
	if [ "$failure_2" != "0" ]
	then

		echo MYSQL DUMP PROBLEM!
		error_message="ERROR sql dump problem on $systemname. BACKUP HAS FAILED! See $backup_logfile"
		send_alert

	fi

else

	echo "Sql backup skipped per config" >> $backup_logfile
	echo "" >> $backup_logfile

fi


#call the run_rsync_backup function from target_commands.sh
run_rsync_backup


#was there a problem with the last group of commands?
if [ "$failure" != "0" ]
then

	echo RSYNC PROBLEM!
	error_message="ERROR rsync problem on $systemname. BACKUP HAS FAILED! See $backup_logfile"
	send_alert

fi


echo started: $start_date >> $backup_logfile
echo finished: $(date) >> $backup_logfile


rm /tmp/backup_script.lock


exit 0

