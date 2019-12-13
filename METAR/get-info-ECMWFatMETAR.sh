#!/bin/bash
### RLP 11-2019
### Descarga predicciones ECMWF para las localidades del METARs
### Compara temperaturas
### Pinta series con R
#set -ex
DIR_DATA=~/data/VALIDACION/
DIR_PLOTS=~/data/VALIDACION/PLOTS
filemetarID=meteoflight_reports.php
AAAAMMDDHH=$(date +%Y%m%d%H%M)
weeknum=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
#scriptName=$(basename $0 .sh)
#lockFile=${DIR_DATA}/${scriptName}_${AAAAMMDDHH}.lock
#if [[ -e ${lockFile} ]] ; then
#  if [[ $(stat -c %Y ${lockFile}) -gt $(date -u +%s --date="180 minutes ago") ]] ; then
#    exit # Problemas: el fichero ${lock} es muy antiguo.
#  else
#    touch ${lockFile}
#  fi
#fi

###Descarga METARs info (LE españoles)
if [[ -e ${filemetarID} ]] ; then
  rm -f $filemetarID
fi
curl http://aire.ogimet.com/meteoflight_reports.php -o meteoflight_reports.php

#nmetar=$(cat $filemetarID | jq '.points[].icao' | wc -l)
metarID=$(cat $filemetarID | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)
filegeonameID=${DIR_DATA}/geonameId-icao-correspondencia.txt #uso este fichero para que gonameID siempre correspoda al mismo METAR

#Truco de Juan para asegurarme que tengo todos los json descargados adecaudamente
ficherosdescargados=0
while [ ${ficherosdescargados} -eq 0 ]
do
  #loop sobre los METARs para descargar la predicción
  #i=0
  for icao in $metarID; do
    #i=$(echo $i + 1 | bc)
    #imet=$(echo $i + 1 | bc)
    #geonameId=$(echo 899999999 - $imet | bc)

    #Se podría descargar los datos del METAR de un día
    #curl http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o METAR-$icao.json
    #cat meteoflight_reports.php\?ICAO\=$icao | jq '.metar_speci[].report' | grep -o '[ M][0-9][0-9]/[0-9][0-9][M ]'
    #cat meteoflight_reports.php\?ICAO\=$icao | jq '.metar_speci[].report' | grep -oE '[0-9]{5}KT'
    geonameId=$(cat $filegeonameID | grep "$icao" | awk '{print $2}')
    lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []' )
    lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
    alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
    if [ ! -e ${DIR_DATA}/PREDIC-$icao.json ]
    then
      curl -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o ${DIR_DATA}/PREDIC-$icao.json
      if [ $? -eq 0 ]
      then
        ##Get forecast info from json file
        cat ${DIR_DATA}/PREDIC-$icao.json  | jq '.dias[].horas[].utime' >pp1
        cat ${DIR_DATA}/PREDIC-$icao.json  | jq '.dias[].horas[].temperatura.valor' >pp2
        fechaSTART=$(cat ${DIR_DATA}/PREDIC-$icao.json  | jq '.dias[0].utime.start')
        fechaSTARTok=$(date --date=@$(echo $fechaSTART/1000 | bc) '+%Y%m%d%H%M')
        paste pp1 pp2 >> ${DIR_DATA}/PREDIC-$icao-$fechaSTARTok.txt

        ##Compara forecast y METAR
        metarfile="${DIR_DATA}/METAR-$icao-$weeknum.txt"
        nts=$(cat $metarfile | wc -l )

        for its in $(seq 1 $nts);do
           temp=$(cat $metarfile | awk '{print $3}' | head -$its | tail -1)
           fechaMETAR=$(cat $metarfile | awk '{print $2}' | head -$its | tail -1)
           fechaMETARok=$(date --date=@$(echo $fechaMETAR/1000 | bc) '+%Y%m%d%H%M')

           echo $(expr \( $fechaMETAR - $fechaSTART \) \/ 3600000) >kkfechaLEAD #horas entre inicio de pasada y METAR
           fechaLEAD=$(cat kkfechaLEAD | awk '{print $0}')
            #For METARs no o'clock data we look for the nearest unix time (sort)
            # min entre prediccion y METAR, fecha predicc, predicc, fecha metar, metar, predicc-metar, fecha METAR, fecha pasada, horas entre pasada y METAR
           cat  ${DIR_DATA}/PREDIC-$icao-$fechaSTARTok.txt | awk '{print  sqrt(($1 - '$fechaMETAR')**2)/60000, $0,'$fechaMETAR','$temp',$2-'$temp','$fechaMETARok','$fechaSTARTok','$fechaLEAD',"'$icao'"}' | sort -n | head -1  >> ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum.txt
           #cat  ${DIR_DATA}/PREDIC-$icao-$fechaSTARTok.txt | awk '{print  sqrt(($1 - '$fechaMETAR')**2)/60000, $0,'$fechaMETAR','$temp',$2-'$temp','$fechaMETARok','$fechaSTARTok','$fechaLEAD','$AAAAMMDDHH',"'$icao'"}' | sort -n | head -1  >> ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum-NEW.txt
        done
        #rm  METAR-$icao.txt PREDIC-$icao.txt pp* PREDIC-$icao.json
#        mv ${DIR_DATA}/PREDIC-$icao.json ${DIR_DATA}/basura/PREDIC-$icao-$AAAAMMDDHH.json
        rm  kk* pp*
        cat ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum.txt | awk '{if (sqrt($6*$6) > 2 ) print "'$icao'",$0,'$fechaLEAD'}' >> ${DIR_DATA}/DIFGT2-predic-metar-$weeknum.txt
        cat ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum.txt | awk '{print sqrt($6*$6), "'$icao'", "'$lon'", "'$lat'", $0,'$fechaLEAD'}' | sort -rn | head -1 >> ${DIR_DATA}/DIFMAX-predic-metar-$weeknum.txt
        #Rscript --vanilla /home/raquel/repos/pruebas/METARs/plot-PREDICvsMETAR.R ${DIR_DATA}/PREDIC-METAR-$icao-$AAAAMMDDHH.txt ${DIR_PLOTS}/PREDIC-METAR-$icao-$AAAAMMDDHH.pdf $icao $AAAAMMDDHH
        #Rscript --vanilla /home/raquel/repos/pruebas/METARs/plot-PREDICvsMETAR.R ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum.txt ${DIR_PLOTS}/PREDIC-METAR-$icao-$weeknum.pdf $icao $AAAAMMDDHH
        Rscript --vanilla /home/raquel/repos/pruebas/METARs/plot-PREDICvsMETAR.R ${DIR_DATA}/PREDIC-METAR-$icao-$weeknum.txt ${DIR_PLOTS}/PREDIC-METAR-$icao-$weeknum.pdf $icao $fechaSTART ${DIR_DATA}/MEAN-BIAS-$icao-$weeknum.txt
      elif [ -e ${DIR_DATA}/PREDIC-$icao.json ]
      then
        rm ${DIR_DATA}/PREDIC-$icao.json
      fi
    fi
  done

  ficherosdescargados=1
  for icao in $metarID; do
    if [ ! -e ${DIR_DATA}/PREDIC-$icao.json ]
    then
      ficherosdescargados=0;
      break;
    fi
  done
done
mv ${DIR_DATA}/PREDIC-*.json ${DIR_DATA}/basura/
#rm -f ${lockFile}
echo 'fin script predicciones'