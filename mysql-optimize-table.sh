#!/bin/bash

USERNAME="root"
HOST="127.0.0.1"
PORT=3306
MYSQL="mysql -u $USERNAME -h $HOST  -P $PORT -B"
MAXLAGTHRESHOLD="1800"
MINLAGTHRESHOLD="300"

function run_optimize(){
    DB=$1
    TABLE=$2
    PARTITION=$3
    RETRY=$4

    if [ $RETRY -gt 0 ]
    then
       echo "Retrying Optimize - RetryCount: $RETRY"
    fi

    SECONDS_BEHIND_MASTER=$($MYSQL -e "SHOW SLAVE STATUS\G"| grep "Seconds_Behind_Master" | awk '{ print $2 }')
    echo "SlaveLag: $SECONDS_BEHIND_MASTER"

    if [ $SECONDS_BEHIND_MASTER -le "$MINLAGTHRESHOLD" ]
    then
        if [ $PARTITION == NULL ]
        then
            $MYSQL -N -e "SET innodb_tmpdir='/var/log/mysql'; USE $DB; OPTIMIZE TABLE $TABLE;"
        else
            $MYSQL -N -e "SET innodb_tmpdir='/var/log/mysql'; USE $DB; ALTER TABLE $TABLE REBUILD PARTITION $PARTITION;"
        fi
    echo "Sleeping for 1m."
    sleep 1m
    elif [[ ( "$SECONDS_BEHIND_MASTER" -gt "$MINLAGTHRESHOLD" ) && ( "$SECONDS_BEHIND_MASTER" -le "$MAXLAGTHRESHOLD" ) ]]
    then
    if [ $PARTITION == NULL ]
        then
            $MYSQL -N -e "SET innodb_tmpdir='/var/log/mysql'; USE $DB; OPTIMIZE TABLE $TABLE;"
        else
            $MYSQL -N -e "SET innodb_tmpdir='/var/log/mysql'; USE $DB; ALTER TABLE $TABLE REBUILD PARTITION $PARTITION;"
        fi
    echo "Sleeping for 5m."
        sleep 5m
    else
    echo "Sleeping for 10m."
        sleep 10m
        RETRY=$((RETRY + 1))
    run_optimize $DB $TABLE $PARTITION $RETRY
    fi
}

$MYSQL -N -e "SELECT TABLE_SCHEMA, TABLE_NAME, DATA_FREE, PARTITION_NAME FROM INFORMATION_SCHEMA.PARTITIONS WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql') AND DATA_FREE > 5000000" | while read TABLE_SCHEMA TABLE_NAME DATA_FREE PARTITION_NAME;do
    echo "Optimizing DB: $TABLE_SCHEMA TABLE: $TABLE_NAME PARTITION: $PARTITION_NAME"
    run_optimize $TABLE_SCHEMA $TABLE_NAME $PARTITION_NAME 0
done
