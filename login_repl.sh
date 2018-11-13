#!/usr/bin/expect
log_user 0
set name [lindex $argv 3]
spawn ssh [lindex $argv 1]@[lindex $argv 0]
expect "yes/no" {
        send "yes\r"
        expect "password" { send "[lindex $argv 2]\r" }
        } "password" { send "[lindex $argv 2]\r" }
expect "$ " {
        send "ssh [lindex $argv 1]@[lindex $argv 4]\r"
        expect "password: " { send "[lindex $argv 5]\r" }
        }
expect "$ " {
        send "cd /home/$name\r"
        send "cat result_replica.txt\r"
}
sleep 10
expect "*\r" { set a "$expect_out(0,string)\n" }
close
puts $a
exit

