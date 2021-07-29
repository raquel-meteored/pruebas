#!/bin/bash
#Buscamos estaciones con diferentes acumulados de precipitación
set -ex

DIR_BASE=/home/raquel/repos/pruebas

i=1; while printf '%d' "$((i++))"; (( i <= 100)); do

  ntiempo=$((1 + $RANDOM % 450000))
  lat=$( mysql -uogimet plocales -se "select latitud from puntos where id_tiempo='$ntiempo'" )
  long=$( mysql -uogimet plocales -se "select longitud from puntos where id_tiempo='$ntiempo'" )

  if (( $(echo "$long > 180" |bc -l) )); then
    lon=$( echo 'scale=4;'$long' - 180' | bc)
  else
    lon="$long"
  fi

  curl -m 10 --connect-timeout 30  'http://localhost/cgi-bin/otf_synop2?latitud='$lat'&longitud='$lon'&radio=1000' -o tmp.json
  jq .[] tmp.json >/dev/null
  check=$?

  if [[ $check != 0 ]]; then
     mv tmp.json error_"$lon"_"$lat".json
     continue
  fi

  if [[ $(jq '.ok' tmp.json) != "false" ]]; then
      dist=$(jq '.Distancia' tmp.json )
      tiempo=$(jq '.Tiempo' tmp.json )
      ult_hora=$(jq '.synop[].hora' tmp.json | tail -1)
      name=$(jq '.nombre' tmp.json )

      valor=$(jq '.synop[].precipitacion.valor' tmp.json )
      tr=$(jq '.synop[].tr' tmp.json )
      hora=$(jq '.synop[].hora' tmp.json )

      jq '.synop[].precipitacion.valor' tmp.json > tmp3
      jq '.synop[].tr' tmp.json > tmp2
      jq '.synop[].hora' tmp.json > tmp1

      paste tmp1 tmp2 tmp3 | tr "\"" " " >> chequeo_PR_situacion_actual.txt

      #VAR3=$( paste <(echo "$hora") <(echo "$valor") <(echo -e "$name" "\n") )

  fi

  if [[ -z "${name}" ]]; then

    echo $i $lat $lon false >> ${DIR_BASE}/chequeo_situacion_actual.txt

  else

    echo $i $name $lat $lon ${ult_hora} $dist $tiempo >> ${DIR_BASE}/chequeo_situacion_actual.txt

  fi

  mv tmp.json kk_"$i".json

done

exit
#for hora in $(seq -w 1 23);do

#   ndato=$(cat ${DIR_BASE}/chequeo_precip_synop.txt | awk '{if ($1=='$hora' && $2==01) print $0}' | wc -l)
#   echo 01 $hora $ndato >> tmp1
#   ndato=$(cat ${DIR_BASE}/chequeo_precip_synop.txt | awk '{if ($1=='$hora' && $2==03) print $0}' | wc -l)
#   echo 03 $hora $ndato >> tmp2

#done
#awk '{if (NF==3) print $0}' tmp1 > ${DIR_BASE}/chequeo_precip_01.txt
#awk '{if (NF==3) print $0}' tmp2 > ${DIR_BASE}/chequeo_precip_03.txt

#rm tmp*

cat>inR2<<EOF
sitact=read.table("${DIR_BASE}/chequeo_situacion_actual.txt")
prec=read.table("${DIR_BASE}/chequeo_PR_situacion_actual.txt")

pdf("${DIR_BASE}/accum_precip.pdf")
plot(prec01[,2],prec01[,3], type="b", col="blue2",lwd=2,xlab="Horas",ylab="Número estaciones")
lines(prec03[,2],prec03[,3], col="tomato", lwd="2", type="b")
legend("topright",c("1 h","3 h"),col=c("blue2","tomato"),lty=c(1,1), lwd=c(2,2),title="Acumulado")

dev.off()
q()
EOF
R CMD BATCH inR2