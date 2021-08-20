#!/bin/bash

STOPSLAVE_CMD="STOP SLAVE;"
STARTSLAVE_CMD="START SLAVE;"
SKIP_COUNTER_CMD="SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;"
DB_HOST="$1"
DB_USER="root"
DB_PORT="3306"
MYSQL_CONNECTION=" -h $DB_HOST -P $DB_PORT -u $DB_USER "

SECONDS_BEHIND_MASTER=$(mysql $MYSQL_CONNECTION -e "SHOW SLAVE STATUS\G"| grep "Seconds_Behind_Master" | awk '{ print $2 }')

while [ "$SECONDS_BEHIND_MASTER" == "NULL" -o "$SECONDS_BEHIND_MASTER" > 0 ]
do
        echo "SLAVE LAG - $SECONDS_BEHIND_MASTER"
        until mysql $MYSQL_CONNECTION -e "show slave status\G;" | grep -i "Slave_SQL_Running: Yes";do
          echo "SKIPING STATEMENT..."
          mysql $MYSQL_CONNECTION -e "$STOPSLAVE_CMD $SKIP_COUNTER_CMD $STARTSLAVE_CMD";
          sleep 1;
        done
        sleep 1;
        SECONDS_BEHIND_MASTER=$(mysql $MYSQL_CONNECTION -e "SHOW SLAVE STATUS\G"| grep "Seconds_Behind_Master" | awk '{ print $2 }')
done
