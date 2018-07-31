###############################################################################
#                                                                             #
#       Este script fue creado por Orlando Correa para monitorear             #
#   el estado de HADR en sistemas SAP con base de datos ORACLE Y DB2          #
#									      #
# FECHA : 26/06/2018                                                          #
# Parametro de Entrada:                                                       #
#                                                                             #
# ID : Con el cual se extrae internamente los siguiente parametros            #
#      de la tabla replicas_init en base de datos MariaDB                     #
# 1. Tipo de Base de datos	                                              #
# 2. Cliente                                                                  #
# 3. Descripcion                                                              #
# 4. SID                                                                      #
# 5. IP instancia central                                                     #
# 6. IP replica								      #
# 7. Usuario instancia central                                                #
# 8. Clave de usuario instancia central					      #
# 9. Usuario de replica							      #	
# 10. Clave de usuario de replica                                             #
# 11. Puerto de comunicacion por el cual se abrira tunnel (solo aplica Oracle)#
###############################################################################

###############################################################################
#									      #
# Licensed Materials - Property of IBM					      #
#									      #
# "Restricted Materials of IBM" 					      #
#									      #
# (C) COPYRIGHT IBM Corp. 1994, 2018 All Rights Reserved.		      #
#									      #
# US Government Users Restricted Rights - Use, duplication or		      #
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.           #
#									      #
###############################################################################

#!/bin/bash

export FECHA=`/bin/date +%Y-%m-%d-%H:%M:%2S`

MYDB="espacios"
MYUSER="espacios"
MYPASS="ibmsap2014"

ID=$1
dbtype=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT dbtype FROM replicas_init where ID='$ID'")
customer=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT customer FROM replicas_init where ID='$ID'")
description=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT description FROM replicas_init where ID='$ID'")
sid=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT sid FROM replicas_init where ID='$ID'")
ip_ci=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT ip_ci FROM replicas_init where ID='$ID'")
ip_replica=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT ip_replica FROM replicas_init where ID='$ID'")
user_unix=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT user_ci FROM replicas_init where ID='$ID'")
pass_unix=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT pass_ci FROM replicas_init where ID='$ID'")
user_replica=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT user_replica FROM replicas_init where ID='$ID'")
pass_replica=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT pass_replica FROM replicas_init where ID='$ID'")
range_log=$(mysql -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT range_log FROM replicas_init where ID='$ID'")

if [ "$customer" == "COLOMBINA" ]; then
sh /home/coecogni/mon_replicas2/Replicas_Colombina.sh $ID "$description"
fi

### ANALISIS DE REPLICAS CON BASE DE DATOS ORACLE

if [ "$dbtype" == "ORACLE" ] || [ "$dbtype" == "oracle" ] && [ "$customer" != "COLOMBINA" ]; then
	ruta_principal=$(ssh -q -o ConnectTimeout=10 -o "StrictHostKeyChecking no" $user_unix@$ip_ci "pwd" ) 2>&1 >/dev/null && status1="OK" || status1="FAIL"
	if [ "$status1" == "FAIL" ]; then
                current_status=$(echo "FAIL")
                replica_result=$(echo "Error en credenciales de conexion a servidor de instancia dentral, revisar")
	else
		ssh -T -q $user_unix@$ip_ci << 'EOF' 2>/dev/null >/dev/null
sqlplus / as sysdba <<!
CONNECT / AS SYSDBA
set sqlblanklines on
exit;
!
sqlplus / as sysdba <<! >result_primary.txt
CONNECT / AS SYSDBA
SELECT (SELECT name FROM V\$DATABASE ) name, (SELECT MAX (sequence#) FROM v\$archived_log WHERE dest_id = 1 ) Current_primary_seq, (SELECT MAX (sequence#) FROM v\$archived_log WHERE TRUNC(next_time) > SYSDATE - 1 AND dest_id = 2 ) max_stby, (SELECT NVL ( (SELECT MAX (sequence#) - MIN (sequence#) FROM v\$archived_log WHERE TRUNC(next_time) > SYSDATE - 1 AND dest_id = 2 AND applied = 'NO' ), 0) FROM DUAL ) "To be applied", ( (SELECT MAX (sequence#) FROM v\$archived_log WHERE dest_id = 1 ) - (SELECT MAX (sequence#) FROM v\$archived_log WHERE dest_id = 2 )) "To be Shipped" FROM DUAL;
exit;
!
EOF
                status2_0="OK"
                status2_0=$(ssh -q $user_unix@$ip_ci " grep -q '[^[:space:]]' result_primary.txt || echo "FAIL"")
                if [ "$status2_0" == "FAIL" ];then
  	            status2="1"
                else
                    status2=$(ssh -q $user_unix@$ip_ci " cat result_primary.txt | grep -i error | wc -l ")
                fi

		execute_shell_pri=$(ssh -q $user_unix@$ip_ci " cat result_primary.txt ")
		if [ $status2 -ne 0 ];then
			ssh -q -o "StrictHostKeyChecking no" $user_unix@$ip_ci "rm -f result_primary.txt " 2>&1 >/dev/null
			current_status=$(echo "FAIL")
                	replica_result=$(echo "Error en ejecucion de cliente SQLPLUS en servidor de instancia central, revisar")
		else
			ssh -q -o "StrictHostKeyChecking no" $user_unix@$ip_ci "rm -f result_primary.txt " 2>&1 >/dev/null
			echo "$execute_shell_pri" > server_primary_output
			current_primary_seq=$(cat server_primary_output | awk ' FNR == 15 { print $2 } ')
			name_pri=$(cat server_primary_output | awk ' FNR == 15 { print $1 } ')
			applied_pri=$(cat server_primary_output | awk ' FNR == 15 { print $3 } '| tr -d $'\r')
			shipped_pri=$(cat server_primary_output | awk ' FNR == 15 { print $4 } '| tr -d $'\r')

			rm -f server_primary_output
			ssh -A -T -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user_unix@$ip_ci ssh -A -T -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 $user_unix@$ip_replica "pwd" 2>&1 >/dev/null && status4="OK" || status4="FAIL"
			if [ "$status4" == "FAIL" ];then
		               	current_status=$(echo "FAIL")
                		replica_result=$(echo "Error en credenciales de conexion a servidor de replica, revisar ")
			else
				ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica << 'EOF' 2>/dev/null >/dev/null
sqlplus / as sysdba <<!
set sqlblanklines on
exit;
!
sqlplus / as sysdba <<! >result_replica.txt
SELECT 'Last Applied : ' Logs,TO_CHAR(next_time,'DD-MON-YY:HH24:MI:SS') TIME,thread#,sequence# FROM v\$archived_log WHERE sequence# = (SELECT MAX(sequence#) FROM v\$archived_log WHERE applied='YES') UNION SELECT 'Last Received : ' Logs,TO_CHAR(next_time,'DD-MON-YY:HH24:MI:SS') TIME,thread#,sequence# FROM v\$archived_log WHERE sequence# = (SELECT MAX(sequence#) FROM v\$archived_log );
exit;
!
EOF
					execute_shell_repl=$(ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica "cat result_replica.txt")
					status5_0=$(ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica " ls -l result_replica.txt | awk '{print \$5}'")
					if [ $status5_0 -eq 0 ];then
						status5="1"
					else
						status5=$(ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica " cat result_replica.txt | grep -i error | wc -l ")
					fi
					if [ $status5 -ne 0 ];then
						ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica "rm -f result_replica.txt" 2>&1 >/dev/null
				                current_status=$(echo "FAIL")
				                replica_result=$(echo "Error en ejecucion de cliente SQLPLUS en servidor replica, revisar")
					else
						ssh -A -T $user_unix@$ip_ci ssh -A -T $user_unix@$ip_replica "rm -f result_replica.txt" 2>&1 >/dev/null
						echo "$execute_shell_repl" > server_replica_output
						applied_repl=$(cat server_replica_output | awk ' FNR == 14 { print $6 } '| tr -d $'\r')
						received_repl=$(cat server_replica_output | awk ' FNR == 15 { print $6 } ' | tr -d $'\r')
						time_received=$(cat server_replica_output | awk ' FNR == 15 { print $4 } ')
						time_applied=$(cat server_replica_output | awk ' FNR == 14 { print $4 } ')

						rm -f server_replica_output
						delta_applied_log=$(awk '{print $1-$2}' <<<"$received_repl $applied_repl");
						delta_current=$(awk '{print $1-$2}' <<<"$current_primary_seq $received_repl");
						if [ "$current_primary_seq" == "$received_repl" ] && (( $delta_applied_log < $range_log )) && (( $delta_current < $range_log )) && [[ $applied_pri = *[!\ ]* ]] && [[ $received_repl = *[!\ ]* ]];then
							current_status=$(echo "OK")
							replica_result=$(echo "La replica esta sincronizada")
						fi

						if [ "$current_primary_seq" == "$received_repl" ] && (( $delta_applied_log > $range_log )) && [[ $current_primary_seq = *[!\ ]* ]] && [[ $received_repl = *[!\ ]* ]];then 
							current_status=$(echo "FAIL")
							replica_result=$(echo "La replica esta sincronizada pero no estan siendo aplicados los logs, revisar")
						fi
	
						if [ "$current_primary_seq" != "$received_repl" ] || (( $delta_current > $range_log )) || (( $delta_applied_log > $range_log ));then
							current_status=$(echo "FAIL")
							replica_result=$(echo "La replica no esta sincronizada, revisar")
						fi
					
					        if [[ $current_primary_seq != *[!\ ]* ]] || [[ $applied_pri != *[!\ ]* ]] || [[ $shipped_pri != *[!\ ]* ]];then
					                current_status=$(echo "FAIL")
					                replica_result=$(echo "La replica no esta sincronizada, revisar")
					        fi
					
					        if [[ $received_repl != *[!\ ]* ]] || [[ $applied_repl != *[!\ ]* ]];then
					                current_status=$(echo "FAIL")
					                replica_result=$(echo "La replica no esta sincronizada, revisar")
					        fi
					
					        if [[ $current_primary_seq != *[!\ ]* ]] || [[ $applied_pri != *[!\ ]* ]] || [[ $shipped_pri != *[!\ ]* ]] && [[ $received_repl != *[!\ ]* ]] || [[ $applied_repl != *[!\ ]* ]];then
					                current_status=$(echo "FAIL")
					                replica_result=$(echo "La replica no esta sincronizada, revisar")
					        fi
                                        fi
                                fi
                        fi
                fi

descripcion_esp=$description"_"$customer"_"$sid"_REPLICA"
echo "{\"TIPO_DB\":\"$dbtype\",\"CLIENTE\":\"$customer\",\"DESCRIPCION\":\"$descripcion_esp\",\"SID\":\"$sid\",\"CURRENT_STATUS\":\"$current_status\",\"LAST_RESULT\":\"$replica_result\",\"LAST_VERIFICATION\":\"$FECHA\"}"

fi

### ANALISIS REPLICAS CON BASE DE DATOS DB2

if [ "$dbtype" == "db2" ] || [ "$dbtype" == "DB2" ]; then
	ssh -q -o ConnectTimeout=10 -o "StrictHostKeyChecking no" $user_unix@$ip_ci "pwd" 2>&1 >/dev/null && status6="OK" || status6="FAIL"
	if [ "$status6" == "FAIL" ];then
                replica_result=$(echo "Error en credenciales de conexion a servidor de instancia central, revisar")
                current_status=$(echo "FAIL")
	else
		rute_db2=$(ssh -q $user_unix@$ip_ci "which db2") 2>&1 >/dev/null && status7="OK" || status7="FAIL"
		if [ "$status7" == "FAIL" ] ;then
                	replica_result=$(echo "Error cliente DB2 no encontrado en instancia central, revisar")
                	current_status=$(echo "FAIL")
		else
                	status_connection=$(ssh -q $user_unix@$ip_ci "$rute_db2 connect to $sid | grep $sid | wc -l" ) 2>&1 >/dev/null
			if [ $status_connection -eq 0 ];then
		                replica_result=$(echo "Error en conexion a base de datos DB2 con sid $SID, no fue encontrada")
                		current_status=$(echo "FAIL")
			else
				rute_home_db2=$(ssh -q $user_unix@$ip_ci "pwd") 2>&1 >/dev/null

				ssh -q -T $user_unix@$ip_ci <<EOF 2>&1 >/dev/null
$rute_db2 connect to $sid 
$rute_db2 'select HADR_SYNCMODE, HADR_STATE,HADR_CONNECT_STATUS,PRIMARY_LOG_FILE,STANDBY_LOG_FILE  from table (mon_get_hadr(NULL))' | egrep '0 record|CONGESTED|DISCONNECTED' | wc -l > $rute_home_db2/STATUS_DB2_REPLICA
$rute_db2 'select HADR_SYNCMODE, HADR_STATE,HADR_CONNECT_STATUS,PRIMARY_LOG_FILE,STANDBY_LOG_FILE  from table (mon_get_hadr(NULL))' > $rute_home_db2/DATOS_DB2
EOF
                		status_replica=$(ssh -q $user_unix@$ip_ci "cat $rute_home_db2/STATUS_DB2_REPLICA") 2>&1 >/dev/null
				if [ $status_replica -ne 0 ];then
                			replica_result=$(echo "La replica no esta sincronizada, revisar")
                			current_status=$(echo "FAIL")
					ssh -q $user_unix@$ip_ci "rm -f $rute_home_db2/STATUS_DB2_REPLICA $rute_home_db2/DATOS_DB2" 2>&1 >/dev/null				
				else
                			replica_result=$(echo "La replica esta sincronizada")
             				current_status=$(echo "OK")
					ssh -q $user_unix@$ip_ci "rm -f $rute_home_db2/STATUS_DB2_REPLICA $rute_home_db2/DATOS_DB2" 2>&1 >/dev/null
				fi
                        fi
                fi
        fi

descripcion_esp=$description"_"$customer"_"$sid"_REPLICA"
echo "{\"TIPO_DB\":\"$dbtype\",\"CLIENTE\":\"$customer\",\"DESCRIPCION\":\"$descripcion_esp\",\"SID\":\"$sid\",\"CURRENT_STATUS\":\"$current_status\",\"LAST_RESULT\":\"$replica_result\",\"LAST_VERIFICATION\":\"$FECHA\"}" 

fi
