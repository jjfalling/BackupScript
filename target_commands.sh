#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#############################################################################
# target_commands.sh
#
# This file is included by the primary backup script and *must* be named 
# target_commands.sh. Otherwise the primary script will be angry.
# You shouldn't run this by hand since it this will not execute any commands.
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
#
#There are four sections:
# *First is to declare a few of things
# *Second is for sql backups rotations. If you don't need this, simply leave 
#  the function empty but do not delete it.
# *Third is for dumping sql databases. If you don't need this, simply leave 
#  the function empty but do not delete it.
# *Fourth is for rsyncing files.
#
#There are also comments above each function/section on what to do.
#
#############################################################################
#First, lets define a few of things


# *** CHANGE THE FOLLOWING ***

#The email to address to send an email address to incase of failure
erroremailaddr="someone@foo.net"

#The domain the host is in, ex: foo.net
domainname="foo.net"

#Where do we want the backup log to go?
backup_logfile="/var/log/backup_log"

#Where are we rsyncing to? (don't put a trailing slash)
rsync_dest="rsync://root@10.10.10.254/office"


#Do we run a sql backup rotation? (yes/no, case sensitive)
run_sqlrotation="no"

#Do we run a sql backup? (yes/no, case sensitive)
run_sqlbackup="no"

#############################################################################
#BACKUP COMMANDS


#Inside this function put the commands you want to use to rotate the sql 
#dumps. THIS WILL NOT RUN UNLESS run_sqlrotation="yes" above.


# ** Put check_sqldump_mv after each line to ensure the command worked. **


function run_sql_backup_rotation {

	rm /var/bla/sqldump3
	check_sqldump_mv

	mv /var/bla/sqldump2 /var/bla/sqldump3
	check_sqldump_mv

	mv /var/bla/sqldump /var/bla/sqldump2
	check_sqldump_mv

}

#***************************************************************************#


#Inside this function put the commands to dump the sql database(s). DO NOT 
#postpend " >> $backup_logfile" to the sql dump commands. The sql dump will 
#endup writing to the logfile instead of the dump file. THIS WILL NOT RUN 
#UNLESS run_sqlbackup="yes" above


# ** Put check_sqldump_mv after each command to ensure the command worked. **

function run_sql_backup_dump {

	echo dump started: $(date) >> $backup_logfile #log when dump started

	mysqldump --all-databases >> /var/bla/sqldump
	check_sqldump_mv

	echo dump finished: $(date) >> $backup_logfile #log when dump finished

}

#***************************************************************************#


#Inside this function put the rsync commands to backup to somewhere. 


# ** Put check_rsync after each command to ensure the command worked. Also 
#  postpend " >> $backup_logfile" to log the command output **


function run_rsync_backup {

	#Do not remove following two lines, this is for server side backup verification.
	
	rsync --delete -DEarvp /tmp/backup_script_status $rsync_dest/tmp/backup_script_status >> $backup_logfile
	check_rsync
	
	#end do not remove


	rsync --delete -DEarvp /root/ $rsync_dest/root/ >> $backup_logfile
	check_rsync
	rsync --delete -DEarvp /usr/local/etc/ $rsync_dest/usr/local/etc/ >> $backup_logfile
	check_rsync
	rsync --delete -DEarvp /usr/local/www/ $rsync_dest/usr/local/www/ >> $backup_logfile
	check_rsync
	rsync --delete -DEarvp /etc/ $rsync_dest/etc/ >> $backup_logfile
	check_rsync


}


#############################################################################


#We dont put an exit command here since this script is included in the main script.

#That's all folks! 

