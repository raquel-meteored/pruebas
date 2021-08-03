#!/bin/bash
#Comprobaciones sobre los jsons de situación actual
set -ex

DIR_BASE=/home/raquel/repos/pruebas

i=1; while printf '%d' "$((i++))"; (( i <= 100)); do

  #Cogemos aleatoriamente localidades detro de la BD plocales
  ntiempo=$((1 + $RANDOM % 450000))
  lat=$( mysql -uogimet plocales -se "select latitud from puntos where id_tiempo='$ntiempo'" )
  long=$( mysql -uogimet plocales -se "select longitud from puntos where id_tiempo='$ntiempo'" )

  if (( $(echo "$long > 180" |bc -l) )); then
    lon=$( echo 'scale=4;'$long' - 180' | bc)
  else
    lon="$long"
  fi

  #Hay estaciones con id pero sin coord. Esto es un poco raro.TODO
  if [[ -z "$lat" ]]; then
    continue
  fi

  #Pedimos situación actual
  curl -m 20 --connect-timeout 60  'http://localhost/cgi-bin/otf_synop?latitud='$lat'&longitud='$lon'&radio=1000&check=true' -o tmp.json
  jq .[] tmp.json >/dev/null 2>&1
  check=$?

  #Guardamos los json que jq no entiende. Esto no funciona bien, se para. TODO
  if [[ $check != 0 ]]; then
     mv tmp.json error_"$lon"_"$lat".json
     continue
  fi

  #Extraemos varibles de interés para el análisis
  if [[ $(jq '.ok' tmp.json) != "false" ]]; then

      dist=$(jq '.Distancia' tmp.json )
      tiempo=$(jq '.Tiempo' tmp.json )
      ult_hora=$(jq '.synop[].hora' tmp.json | tail -1 | tr "\"" " " )
      name=$(jq '.nombre' tmp.json )

      jq '.synop[].hora' tmp.json > tmp1
      jq '.synop[].tr' tmp.json > tmp2
      jq '.synop[].precipitacion.valor' tmp.json > tmp3

      paste tmp1 tmp2 tmp3 | tr "\"" " " >> chequeo_situacion_actual_PR.txt
  fi

  #Analizamos el porcentaje de estaciones con dato
  if [[ $(jq '.ok' tmp.json) == "false" ]]; then

    echo $(date -u '+%H') false $lat $lon  >> ${DIR_BASE}/chequeo_situacion_actual_false.txt

  else

    echo  ${ult_hora} $dist $tiempo $lat $lon $name >> ${DIR_BASE}/chequeo_situacion_actual_dist.txt

  fi

  #mv tmp.json kk_"$i".json

done


#Analisis por horas
for hora in $(seq -w 1 23);do

   ndato1=$(cat ${DIR_BASE}/chequeo_situacion_actual_PR.txt | awk '{if ($1=='$hora' && $2==1) print $0}' | wc -l)
   ndato3=$(cat ${DIR_BASE}/chequeo_situacion_actual_PR.txt | awk '{if ($1=='$hora' && $2==3) print $0}' | wc -l)

   nfallos=$(cat ${DIR_BASE}/chequeo_situacion_actual_false.txt | awk '{if ($1=='$hora') print $0}' | wc -l )
   naciertos=$(cat ${DIR_BASE}/chequeo_situacion_actual_dist.txt | awk '{if ($1=='$hora') print $0}' | wc -l )

   if [[ -z "$ndato1" ]];then
       ndato1=0
   fi

      if [[ -z "$ndato3" ]];then
       ndato3=0
   fi

   echo $hora 1 $ndato1 3 $ndato3  >> tmp-prec
   echo $hora $nfallos $naciertos >> tmp-fallos

done


awk '{if (NF==5) print $0}' tmp-prec > ${DIR_BASE}/chequeo_PR.txt
awk '{if (NF==3) print $0}' tmp-fallos > ${DIR_BASE}/chequeo_fallos.txt
rm tmp-prec tmp-fallos

#Pintamos el análisis con R
cat>inR2<<EOF
sitact=read.table("${DIR_BASE}/chequeo_situacion_actual_dist.txt")
prec=read.table("${DIR_BASE}/chequeo_situacion_actual_PR.txt")
prechoras=read.table("${DIR_BASE}/chequeo_PR.txt")
fallos=read.table("${DIR_BASE}/chequeo_fallos.txt")

pr1h=subset(prec,prec[,2]==1)
pr3h=subset(prec,prec[,2]==3)


pdf("${DIR_BASE}/hist_dist.pdf")
hist(sitact[,2], main="Distacia synop petición", xlab="Distacia (m)")

pdf("${DIR_BASE}/hist_tiempo.pdf")
hist(sitact[,3], main="Tiempo synop petición", xlab="Tiempo (s)")

pdf("${DIR_BASE}/horas_vs_fallos.pdf")
plot(fallos[,1], fallos[,3], type="b", xlab="Horas", ylab="# estaciones",col="blue", main="Estaciones con observaciones vs vacías")
lines(fallos[,2],type="b",col="tomato")
legend("topright",lty=c(1,1),col=c("blue","tomato"),c("con datos","vacías"),title="Estaciones")


pdf("${DIR_BASE}/horas_vs_estprec.pdf")
lim=max(prechoras[,3],prechoras[,5])
plot(prechoras[,1],prechoras[,3],type="b", col="blue", ylim=c(0,lim), xlab="Horas", ylab="# estaciones", main="Estacion con precip. horaria y trihoraria")
lines(prechoras[,5],type="b",col="tomato")
legend("topright",lty=c(1,1),col=c("blue","tomato"),c("1h","3h"))

dev.off()
q()
EOF
R CMD BATCH inR2

rm tmp*