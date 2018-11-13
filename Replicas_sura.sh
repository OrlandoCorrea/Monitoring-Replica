#!/bin/bash
#!/usr/bin/expect


export FECHA=`/bin/date +%Y-%m-%d-%H:%M:%2S`

MYDB="espacios"
MYUSER="espacios"
MYPASS="ibmsap2014"

ID=$1
ALL=$(mysql --connect-timeout=1 -D$MYDB -u$MYUSER -p$MYPASS -se "SELECT concat(dbtype,'|',customer,'|',description,'|',sid,'|',ip_ci,'|',ip_replica,'|',user_ci,'|',range_log,'|',user_application,'|',pass_ci,'|',pass_replica) FROM replicas_init where ID='$ID';")
dbtype=$(echo "$ALL" | awk -F "|" '{print $1}')
customer=$(echo "$ALL" | awk -F "|" '{print $2}')
description=$(echo "$ALL" | awk -F "|" '{print $3}')
sid=$(echo "$ALL" | awk -F "|" '{print $4}')
ip_ci=$(echo "$ALL" | awk -F "|" '{print $5}')
ip_replica=$(echo "$ALL" | awk -F "|" '{print $6}')
user_unix=$(echo "$ALL" | awk -F "|" '{print $7}')
range_log=$(echo "$ALL" | awk -F "|" '{print $8}')
user_application=$(echo "$ALL" | awk -F "|" '{print $9}')
pass_ci=$(echo "$ALL" | awk -F "|" '{print $10}')
pass_repl=$(echo "$ALL" | awk -F "|" '{print $11}')

PASS=$pass_ci
PASSR=$pass_repl

ruta_principal=$(SSHPASS=$PASS sshpass -e $pass ssh -q -o ConnectTimeout=10 -o "StrictHostKeyChecking no" $user_unix@$ip_ci "pwd" ) 2>&1 >/dev/null && status1="OK" || status1="FAIL"
if [ "$status1" == "FAIL" ]; then
  current_status=$(echo "FAIL")
  replica_result=$(echo "Error en credenciales de conexion a servidor de instancia dentral, revisar")
else
  status2_0="OK"
  status2_0=$(SSHPASS=$PASS sshpass -e $pass ssh -q $user_unix@$ip_ci " cd /home/$user_application && grep -q '[^[:space:]]' result_primary.txt || echo "FAIL"")
  if [ "$status2_0" == "FAIL" ];then
    status2="1"
  else
    status2=$(SSHPASS=$PASS sshpass -e $pass ssh -q $user_unix@$ip_ci " cd /home/$user_application && cat result_primary.txt | grep -i error | wc -l ")
  fi
  execute_shell_pri=$(SSHPASS=$PASS sshpass -e $pass ssh -q $user_unix@$ip_ci " cd /home/$user_application && cat result_primary.txt ")
  if [ $status2 -ne 0 ];then
    current_status=$(echo "FAIL")
    replica_result=$(echo "Error en ejecucion de cliente SQLPLUS en servidor de instancia central, revisar")
  else
    current_primary_seq=$(echo "$execute_shell_pri" | awk ' FNR == 14 { print $2 } ')
    name_pri=$(echo "$execute_shell_pri" | awk ' FNR == 14 { print $1 } ')
    applied_pri=$(echo "$execute_shell_pri" | awk ' FNR == 14 { print $4 } '| tr -d $'\r')
    shipped_pri=$(echo "$execute_shell_pri" | awk ' FNR == 14 { print $5 } '| tr -d $'\r')
    echo "$current_primary_seq,$name_pri,$applied_pri,$shipped_pri"
    cd /home/coecogni/mon_replicas2
    ./login_repl.sh "$ip_ci" "$user_unix" "$PASS" "$user_application" "$ip_replica" "$pass_repl" > data_real.txt
    status4="OK"
    if [ "$status4" == "FAIL" ];then
      current_status=$(echo "FAIL")
      replica_result=$(echo "Error en credenciales de conexion a servidor de replica, revisar ")
    else
      execute_shell_repl=$(cd /home/coecogni/mon_replicas2 && cat data_real.txt)
      status5_0=$(cd /home/coecogni/mon_replicas2 && ls -l data_real.txt | awk '{print $5}')
      if [ $status5_0 -eq 0 ];then
        status5="1"
      else
        status5=$(cd /home/coecogni/mon_replicas2 && cat data_real.txt | grep -i error | wc -l)
      fi
      if [ $status5 -ne 0 ];then
        current_status=$(echo "FAIL")
        replica_result=$(echo "Error en ejecucion de cliente SQLPLUS en servidor replica, revisar")
      else
        applied_repl=$(echo "$execute_shell_repl" | awk ' FNR == 16 { print $6 } '| tr -d $'\r')
        received_repl=$(echo "$execute_shell_repl" | awk ' FNR == 17 { print $6 } ' | tr -d $'\r')
        time_received=$(echo "$execute_shell_repl" | awk ' FNR == 17 { print $4 } ')
        time_applied=$(echo "$execute_shell_repl" | awk ' FNR == 16 { print $4 } ')

        delta_applied_log=$(awk '{print $1-$2}' <<<"$received_repl $applied_repl");
        delta_current=$(awk '{print $1-$2}' <<<"$current_primary_seq $received_repl");
        echo "$execute_shell_repl"
        echo "$applied_repl"
        echo "$received_repl"
        echo "$time_received"
        echo "$time_applied"
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

descripcion_esp=$description"_"$customer"_"$sid"_REPLICA"
echo "{\"TIPO_DB\":\"$dbtype\",\"CLIENTE\":\"$customer\",\"DESCRIPCION\":\"$descripcion_esp\",\"SID\":\"$sid\",\"CURRENT_STATUS\":\"$current_status\",\"LAST_RESULT\":\"$replica_result\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"

fi
