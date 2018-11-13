#!/usr/bin/expect

log_user 0

spawn ssh [lindex $argv 1]@[lindex $argv 0]
expect "yes/no" {
        send "yes\r"
        expect "password" { send "[lindex $argv 2]\r" }
        } "password" { send "[lindex $argv 2]\r" }
expect "$ " {
        send "sudo su - [lindex $argv 3]\r"
        expect "Password: " { send "[lindex $argv 2]\r" }
        expect "> " {
                       send "sqlplus / as sysdba <<!\r"
                       send "set sqlblanklines on\r"
                       send "exit;\r"
                       send "!\r"
                       send "sqlplus / as sysdba <<! >result_primary.txt \r"
                       send "SELECT (SELECT name FROM V\\\$DATABASE ) name, (SELECT MAX (sequence#) FROM v\\\$archived_log WHERE dest_id = 1 ) Current_primary_seq, (SELECT MAX (sequence#) FROM v\\\$archived_log WHERE TRUNC(next_time) > SYSDATE - 1 AND dest_id = 2 ) max_stby, (SELECT NVL ( (SELECT MAX (sequence#) - MIN (sequence#) FROM v\\\$archived_log WHERE TRUNC(next_time) > SYSDATE - 1 AND dest_id = 2 AND applied = 'NO'), 0) FROM DUAL ) \"To be applied\", ( (SELECT MAX (sequence#) FROM v\\\$archived_log WHERE dest_id = 1 ) - (SELECT MAX (sequence#) FROM v\\\$archived_log WHERE dest_id = 2 )) \"To be Shipped\" FROM DUAL;\r"
                       send "exit;\r"
                       send "!\r"
                       send "exit\r"
                       send "ssh [lindex $argv 1]@[lindex $argv 4]\r"
                       expect "password: " { send "[lindex $argv 5]\r" }
                       expect "$ " { send "sudo su - [lindex $argv 3]\r"
                                     expect "Password: " { send "[lindex $argv 5]\r" }}
                       expect ">" {
                                send "sqlplus / as sysdba <<!\r"
                                send "set sqlblanklines on\r"
                                send "exit;\r"
                                send "!\r"
                                send "sqlplus / as sysdba <<! >result_replica.txt\r"
                                send "SELECT 'Last Applied : ' Logs,TO_CHAR(next_time,'DD-MON-YY:HH24:MI:SS') TIME,thread#,sequence# FROM v\\\$archived_log WHERE sequence# = (SELECT MAX(sequence#) FROM v\\\$archived_log WHERE applied='YES') UNION SELECT 'Last Received : ' Logs,TO_CHAR(next_time,'DD-MON-YY:HH24:MI:SS') TIME,thread#,sequence# FROM v\\\$archived_log WHERE sequence# = (SELECT MAX(sequence#) FROM v\\\$archived_log );\r"
                                send "exit;\r"
                                send "!\r"
                                send "exit\r"
                                send "exit\r"
                       expect "$ " { send "exit\r" }
}
}
}
expect eof

