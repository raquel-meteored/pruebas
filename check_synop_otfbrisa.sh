#!/bin/bash
#Comprobaciones sobre los jsons de situación actual

DIR_BASE=/home/raquel/repos/pruebas

while IFS=, read -r ciudad lat lon idstation
do

  #Pedimos situación actual
  rm -f tmp.json

  { time curl -s -m 20 --connect-timeout 60  'http://brisa.ogimet.com/cgi-bin/otf_synop?latitud='$lat'&longitud='$lon'&radio=10&check=true' -o ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json 2>1 ; } 2> time.log
  cat time.log | grep "real" | tr "m" " " | tr "s" " " | tr "," "." | awk '{print $3}'  >> ${DIR_BASE}/chequeo_situacion_actual_tiempo_peticion_Feedbackcities.txt 

  jq .[] ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json >/dev/null 2>&1
  check=$?

  #Guardamos los json que jq no entiende. Esto no funciona bien, se para. TODO
  if [[ $check != 0 ]]; then
     mv ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json ${DIR_BASE}/error_"$lon"_"$lat".json
     continue
  else
     cp ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json tmp.json
  fi

  #Extraemos varibles de interés para el análisis
  if [[ $(jq '.ok' tmp.json) != "false" ]]; then

      dist=$(jq '.Distancia' tmp.json )
      tiempo=$(jq '.Tiempo' tmp.json )
      ult_hora=$(jq '.horas[].hora' tmp.json | tail -1 | tr "\"" " " | tr ":" " " | awk '{print $1}')
      ult_min=$(jq '.horas[].hora' tmp.json | tail -1 | tr "\"" " " | tr ":" " " | awk '{print $2}')
      name=$(jq '.nombre' tmp.json )

      jq '.horas[].hora' tmp.json > tmp1
      jq '.horas[].horaBD' tmp.json > tmpBD
      jq '.horas[].tr' tmp.json > tmp2
      jq '.horas[].precipitacion.valor' tmp.json > tmp3
      jq '.horas[].simbolo.valor' tmp.json > tmpsimb
      jq '.horas[].simbolo.valor2' tmp.json > tmpsimb2

      paste tmp1 tmp2 tmp3 | tr "\"" " " >> ${DIR_BASE}/PR_Feedbackcities.txt
      echo  $(date -u '+%H') $(date -u '+%M') ${ult_hora} ${ult_min} $dist $tiempo $lat $lon $ciudad $idstation | awk '{if (NF==10) print $0}' >> ${DIR_BASE}/chequeo_situacion_actual_dist_Feedbackcities.txt
      paste tmpsimb tmpsimb2 | awk '{ if ($1==$2) print $1, "'$ciudad'", "ok"; else print $1, "'$ciudad'", "ko" }' >> ${DIR_BASE}/chequeo_simbolos.txt 
      paste tmp1 tmpBD >> ${DIR_BASE}/chequeo_tiempoBD.txt
      tmpBDmean=$(awk '{s+=$2}END{printf "%.3f\n", s/NR}' ${DIR_BASE}/chequeo_tiempoBD.txt)
      echo $ciudad $tmpBDmean >> ${DIR_BASE}/chequeo_tiempoBDmean.txt
  else

    echo $(date -u '+%H') false $lat $lon  >> ${DIR_BASE}/chequeo_situacion_actual_false_Feedbackcities.txt

  fi

done < ${DIR_BASE}/ciudades_feedback.csv

#Analisis por horas
for hora in $(seq -w 0 23);do

   ndato1=$(cat ${DIR_BASE}/PR_Feedbackcities.txt | awk '{if ($1=='$hora' && $2==1) print $0}' | wc -l)
   ndato3=$(cat ${DIR_BASE}/PR_Feedbackcities.txt | awk '{if ($1=='$hora' && $2==3) print $0}' | wc -l)
   ndato=$(cat ${DIR_BASE}/PR_Feedbackcities.txt | awk '{if ($1=='$hora') print $0}' | wc -l)

   nfallos=$(cat ${DIR_BASE}/chequeo_situacion_actual_false_Feedbackcities.txt | awk '{if ($1=='$hora') print $0}' | wc -l )
   naciertos=$(cat ${DIR_BASE}/chequeo_situacion_actual_dist_Feedbackcities.txt | awk '{if ($1=='$hora') print $0}' | wc -l )

   if [[ -z "$ndato1" ]];then
       ndato1=0
   fi

      if [[ -z "$ndato3" ]];then
       ndato3=0
   fi

   echo $hora 1 $ndato1 3 $ndato3 $ndato >> tmp-prec
   echo $hora $nfallos $naciertos >> tmp-fallos

done

awk '{if (NF==6) print $0}' tmp-prec > ${DIR_BASE}/chequeo_situacion_actual_PR_Feedbackcities.txt
awk '{if (NF==3) print $0}' tmp-fallos > ${DIR_BASE}/chequeo_situacion_actual_fallos_Feedbackcities.txt
rm tmp-prec tmp-fallos

#Pintamos el análisis con R
cat>inR2<<EOF

tiempo=read.table("${DIR_BASE}/chequeo_situacion_actual_tiempo_peticion_Feedbackcities.txt")
sitact=read.table("${DIR_BASE}/chequeo_situacion_actual_dist_Feedbackcities.txt")
prechoras=read.table("${DIR_BASE}/chequeo_situacion_actual_PR_Feedbackcities.txt")
fallos=read.table("${DIR_BASE}/chequeo_situacion_actual_fallos_Feedbackcities.txt")
tiempoBD=read.table("${DIR_BASE}/chequeo_tiempoBD.txt")
tiempoBDmean=read.table("${DIR_BASE}/chequeo_tiempoBDmean.txt")

totales=numeric(length(fallos[,2]))
totales=fallos[,3] + fallos[,2]

#Retardo= tiempo entre petición y último synop con dato

#¿qué retardo es más frecuente?
png("${DIR_BASE}/hist_tiempo_Feedbackcities.png")
hist(subset(sitact[,6],sitact[,6]<7200), main="Tiempo desde la petición hasta synop disponible", xlab="Tiempo (s)", breaks = seq(0, 7200, 200),xaxp=c(0,7200,36),col="lightblue")

#¿qué retardo en llegar a la BD?
png("${DIR_BASE}/hist_tiempoBD_Feedbackcities.png")
hist(subset(tiempoBD[,2],tiempoBD[,2]<7200), main="Tiempo que tarda en llegar a la BD", xlab="Tiempo (s)", breaks = seq(0, 7200, 200),xaxp=c(0,7200,36),col="orange")

#¿el retardo depende de la estación ?
png("${DIR_BASE}/estacion_vs_tiempo_Feedbackcities.png")
plot(sitact[,6], sitact[,9], pch=16, yaxt="n", ylab="", xlab="Tiempo entre petición y synop disponible (s)", main="Estación vs tiempo petición synop disponible")
axis(2,at=seq(1, length(sitact[,9])), as.character(sitact[,9]),las=1)

#¿A qué minuto tiene dato las estaciones?
png("${DIR_BASE}/estation_vs_tiempoBDmean_Feedbackcities.png")
plot(tiempoBDmean[,2], tiempoBDmean[,1], pch=16 , yaxt="n", ylab="", xlab="Tiempo (s)", main="Tiempo que tarda en llegar la info del Synop a la BD")
axis(2,at=seq(1, length(tiempoBDmean[,1])), as.character(tiempoBDmean[,1]),las=1)

#¿el retardo depende de la hora de petición?
png("${DIR_BASE}/horasPeticion_vs_tiempo_Feedbackcities.png")
plot(sitact[,1],sitact[,6], pch=16, col="red",  xlab="Hora de petición", ylab="Tiempo entre petición y synop disponible (s)")

#¿el retardo depende del minudo de petición?
png("${DIR_BASE}/minPeticion_vs_tiempo_Feedbackcities.png")
plot(sitact[,2],sitact[,6], pch=16, col="blue",  xlab="Minuto de petición", ylab="Tiempo entre petición y synop disponible (s)")

#
png("${DIR_BASE}/hist_velocidad_Feedbackcities.png")
hist(subset(tiempo[,1],tiempo[,1]<1), main="Velocidad de descarga del json", xlab="Tiempo de descarga (s)",xaxp=c(0,1,10),xlim=c(0,1),col="pink",prob=TRUE)


dev.off()
q()
EOF
R CMD BATCH inR2

rm tmp*
