#!/bin/bash
ID=$1
DESCRIPTION=$2

export FECHA=`/bin/date +%Y-%m-%d-%H:%M:%2S`

echo >informe_replicas.log
echo "** COLOMBINA ** --- CRM:" >>informe_replicas.log
ssh ibmsaptp@sapcrmprd "~/informe_replica.sh" >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo "** COLOMBINA ** --- ERP:" >>informe_replicas.log
ssh ibmsaptp@prosap3 "~/informe_replica.sh" >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo "** COLOMBINA ** --- PI:" >>informe_replicas.log
ssh ibmsaptp@sappi2 "~/informe_replica.sh" >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo "** COLOMBINA ** --- PORTAL:" >>informe_replicas.log
ssh ibmsaptp@proep2 "~/informe_replica.sh" >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log
echo >>informe_replicas.log

recev_crm=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 6 { print $6 } ')
applied_crm=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 5 { print $6 } ')
delta_crm=$(awk '{print $1-$2}' <<<"$recev_crm $applied_crm");


if [ "$DESCRIPTION" == "CRM_PRODUCCION_CRP_SAPCRMPRD" ];then
        if (( $delta_crm < 10 ));then
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"CRM PRD_COLOMBINA_CRP_REPLICA\",\"SID\":\"CRP\",\"CURRENT_STATUS\":\"OK\",\"LAST_RESULT\":\"La replica esta sincronizada, LOG Productivo:'$recev_crm' - LOG Replica:'$applied_crm'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        else
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"CRM PRD_COLOMBINA_CRP_REPLICA\",\"SID\":\"CRP\",\"CURRENT_STATUS\":\"FAIL\",\"LAST_RESULT\":\"La replica no esta sincronizada, LOG Productivo:'$recev_crm' - LOG Replica:'$applied_crm'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        fi
fi

recev_pro=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 12 { print $6 } ')
applied_pro=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 11 { print $6 } ')
delta_pro=$(awk '{print $1-$2}' <<<"$recev_pro $applied_pro");

if [ "$DESCRIPTION" == "ERP_PRODUCCION_PROSAP3" ];then
        if (( $delta_pro < 10 ));then
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"ERP PRD_COLOMBINA_PRO_REPLICA\",\"SID\":\"PRO\",\"CURRENT_STATUS\":\"OK\"\,\"LAST_RESULT\":\"La replica esta sincronizada, LOG Productivo:'$recev_pro' - LOG Replica:'$applied_pro'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        else
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"ERP PRD_COLOMBINA_PRO_REPLICA\",\"SID\":\"PRO\",\"CURRENT_STATUS\":\"FAIL\",\"LAST_RESULT\":\"La replica no esta sincronizada, LOG Productivo:'$recev_pro' - LOG Replica:'$applied_pro'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        fi
fi

recev_pic=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 18 { print $6 } ')
applied_pic=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 17 { print $6 } ')
delta_pic=$(awk '{print $1-$2}' <<<"$recev_pic $applied_pic");

if [ "$DESCRIPTION" == "PI_PRODUCCION_PIC_SAPPI2" ];then
        if (( $delta_pic < 10 ));then
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"PI PRD_COLOMBINA_PIC_REPLICA\",\"SID\":\"PIC\",\"CURRENT_STATUS\":\"OK\"\,\"LAST_RESULT\":\"La replica esta sincronizada, LOG Productivo:'$recev_pic' - LOG Replica:'$applied_pic'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        else
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"PI PRD_COLOMBINA_PIC_REPLICA\",\"SID\":\"PIC\",\"CURRENT_STATUS\":\"FAIL\",\"LAST_RESULT\":\"La replica no esta sincronizada, LOG Productivo:'$recev_pic' - LOG Replica:'$applied_pic'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        fi
fi
recev_ppc=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 24 { print $6 } ')
applied_ppc=$(cat informe_replicas.log | awk ' /COLOMBINA/ { print " " ; print " " ; print $0 } /THREAD/ { print $0 } /Last/ { print $0 } ' | awk ' FNR == 23 { print $6 } ')
delta_ppc=$(awk '{print $1-$2}' <<<"$recev_ppc $applied_ppc");

if [ "$DESCRIPTION" == "PORTAL_PRODUCTIVO_PPC_PROEP" ];then
        if (( $delta_ppc < 10 ));then
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"PORTAL PRD_COLOMBINA_PPC_REPLICA\",\"SID\":\"PPC\",\"CURRENT_STATUS\":\"OK\"\,\"LAST_RESULT\":\"La replica esta sincronizada, LOG Producto:'$recev_ppc' - LOG Replica:'$applied_ppc'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        else
                echo "{\"TIPO_DB\":\"ORACLE\",\"CLIENTE\":\"COLOMBINA\",\"DESCRIPCION\":\"PORTAL PRD_COLOMBINA_PPC_REPLICA\",\"SID\":\"PPC\",\"CURRENT_STATUS\":\"FAIL\",\"LAST_RESULT\":\"La replica no esta sincronizada, LOG Producto:'$recev_ppc' - LOG Replica:'$applied_ppc'\",\"LAST_VERIFICATION\":\"$FECHA\"}" > $ID".json"
        fi
fi

rm -f informe_replicas.log
~                                                  
