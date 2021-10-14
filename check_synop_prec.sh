#!/bin/bash
#Comprobaciones sobre los jsons de situación actual

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
  rm -f tmp.json
  echo $(date "+%s") $lat $lon $ntiempo >> ${DIR_BASE}/prueba-coord.txt
  curl -s -m 20 --connect-timeout 60  'http://localhost/cgi-bin/otf_synop?latitud='$lat'&longitud='$lon'&radio=1000&check=true' -o ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json
  cp ${DIR_BASE}/basura/sitactual_"$lon"_"$lat".json tmp.json
  jq .[] tmp.json >/dev/null 2>&1
  check=$?

  #Guardamos los json que jq no entiende. Esto no funciona bien, se para. TODO
  if [[ $check != 0 ]]; then
     mv tmp.json ${DIR_BASE}/error_"$lon"_"$lat".json
     continue
  fi

  #Extraemos varibles de interés para el análisis
  if [[ $(jq '.ok' tmp.json) != "false" ]]; then

      dist=$(jq '.Distancia' tmp.json )
      tiempo=$(jq '.Tiempo' tmp.json )
      ult_hora=$(jq '.horas[].hora' tmp.json | tail -1 | tr "\"" " " | tr ":" " " | awk '{print $1}')
      name=$(jq '.nombre' tmp.json )

      jq '.horas[].hora' tmp.json > tmp1
      jq '.horas[].tr' tmp.json > tmp2
      jq '.horas[].precipitacion.valor' tmp.json > tmp3

      paste tmp1 tmp2 tmp3 | tr "\"" " " >> ${DIR_BASE}/chequeo_situacion_actual_PR.txt
      echo  ${ult_hora} $dist $tiempo $lat $lon $name | awk '{if (NF==7) print $0}' >> ${DIR_BASE}/chequeo_situacion_actual_dist.txt

      if [[ ${ult_hora} > 10 ]]; then
        echo ${ult_hora} $(jq '.horas[].nf' tmp.json | tail -1) | awk '{print $1/$2}' >> ${DIR_BASE}/chequeo_situacion_actual_restemp.txt
      fi
     
  else
    echo $(date -u '+%H') false $lat $lon  >> ${DIR_BASE}/chequeo_situacion_actual_false.txt
  fi


done

#Analisis por horas
for hora in $(seq -w 0 23);do

   ndato1=$(cat ${DIR_BASE}/chequeo_situacion_actual_PR.txt | awk '{if ($1=='$hora' && $2==1) print $0}' | wc -l)
   ndato3=$(cat ${DIR_BASE}/chequeo_situacion_actual_PR.txt | awk '{if ($1=='$hora' && $2==3) print $0}' | wc -l)
   ndato=$(cat ${DIR_BASE}/chequeo_situacion_actual_PR.txt | awk '{if ($1=='$hora') print $0}' | wc -l)

   nfallos=$(cat ${DIR_BASE}/chequeo_situacion_actual_false.txt | awk '{if ($1=='$hora') print $0}' | wc -l )
   naciertos=$(cat ${DIR_BASE}/chequeo_situacion_actual_dist.txt | awk '{if ($1=='$hora') print $0}' | wc -l )

   if [[ -z "$ndato1" ]];then
       ndato1=0
   fi

      if [[ -z "$ndato3" ]];then
       ndato3=0
   fi

   echo $hora 1 $ndato1 3 $ndato3 $ndato >> tmp-prec
   echo $hora $nfallos $naciertos >> tmp-fallos

done

awk '{if (NF==6) print $0}' tmp-prec > ${DIR_BASE}/chequeo_PR.txt
awk '{if (NF==3) print $0}' tmp-fallos > ${DIR_BASE}/chequeo_fallos.txt
rm tmp-prec tmp-fallos

#Pintamos el análisis con R
cat>inR2<<EOF
sitact=read.table("${DIR_BASE}/chequeo_situacion_actual_dist.txt")
prechoras=read.table("${DIR_BASE}/chequeo_PR.txt")
fallos=read.table("${DIR_BASE}/chequeo_fallos.txt")
restemp=read.table("${DIR_BASE}/chequeo_situacion_actual_restemp.txt")

totales=numeric(length(fallos[,2]))
totales=fallos[,3] + fallos[,2]

png("${DIR_BASE}/hist_restemp.png")
hist(restemp[,1], main="Resolución temporal", xlab="Res. Temp. (Horas)",xaxp=c(0,24,12),xlim=c(0,24),col="lightgreen",prob=TRUE)

png("${DIR_BASE}/hist_dist.png")
hist(subset(sitact[,2],sitact[,2]<110), main="Distancia entre synop y la petición", xlab="Distacia (km)",xaxp=c(0,110,11),xlim=c(0,110),col="lightyellow",prob=TRUE)

png("${DIR_BASE}/hist_tiempo.png")
hist(subset(sitact[,3],sitact[,3]<7200), main="Tiempo desde la petición hasta synop disponible", xlab="Tiempo (s)", breaks = seq(0, 7200, 200),xaxp=c(0,7200,36),col="lightblue")

png("${DIR_BASE}/horas_vs_fallos.png")
plot(fallos[,1], 100*fallos[,3]/totales, type="b", xlab="Hora de petición", ylab="% estaciones",col="blue", main="Porcentajes de estaciones sin dato",xaxp=c(0,23,23))
lines(fallos[,1],fallos[,2],type="b",col="tomato")
legend("topright",lty=c(1,1),col=c("blue","tomato"),c("con datos","vacías"),title="Estaciones")

png("${DIR_BASE}/horas_vs_estprec.png")
lim=max(100*prechoras[,3]/prechoras[,6],100*prechoras[,5]/prechoras[,6])
plot(prechoras[,1],100*prechoras[,3]/prechoras[,6],type="b", col="blue", ylim=c(0,lim), xlab="Hora con dato", ylab="% estaciones", main="Estación con precip. horaria y trihoraria",xaxp=c(0,23,23))
lines(prechoras[,1],100*prechoras[,5]/prechoras[,6],type="b",col="tomato")
legend("topright",lty=c(1,1),col=c("blue","tomato"),c("1h","3h"))

distumb=seq(0,100,2)
probdist=numeric(length(distumb))
b=length(sitact[,2])

for (i in 1:length(distumb)){
  a=length(subset(sitact[,2],sitact[,2]<distumb[i]))
  probdist[i]=100*a/b
}

png("${DIR_BASE}/probdist.png")
plot(distumb,probdist,xlab="Distancia entre petición y observación (km)",ylab="Porcentajes de peticones con observación (%)")
abline(h=50,col="red")
abline(v=10,col="green")

distumb=seq(0,7200,60)
probdist=numeric(length(distumb))
b=length(sitact[,3])

for (i in 1:length(distumb)){
  a=length(subset(sitact[,3],sitact[,3]<distumb[i]))
  probdist[i]=100*a/b
}

png("${DIR_BASE}/probtiempo.png")
plot(distumb,probdist,xlab="Tiempo entre petición y observación (s)",ylab="Porcentajes de peticones con observación (%)")
abline(h=50,col="red")
abline(v=3600,col="green")


dev.off()
q()
EOF
R CMD BATCH inR2

rm tmp*
