#!/bin/bash
###Download ECMWF at METARs locations and compare temperature
set -ex
DIR_DATA=~/data/VALIDACION/
DIR_PLOTS=~/data/VALIDACION/PLOTS
AAAAMMDDHH=$(date +%Y%m%d%H%M)
scriptName=$(basename $0 .sh)
lockFile=${DIR_DATA}/${scriptName}_${AAAAMMDDHH}.lock
filemetarID=meteoflight_reports.php

# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
#if [[ -e ${lockFile} ]] ; then
#  if [[ $(stat -c %Y ${lockFile}) -gt $(date -u +%s --date="180 minutes ago") ]] ; then
#    exit # Problemas: el fichero ${lock} es muy antiguo.
#  else
#    touch ${lockFile}
#  fi
#fi

###Dowload METARs info
if [[ -e ${lockFile} ]] ; then
  rm -f $filemetarID
fi

curl http://aire.ogimet.com/meteoflight_reports.php -o meteoflight_reports.php

nmetar=$(cat $filemetarID | jq '.points[].icao' | wc -l)
metarID=$(cat $filemetarID | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)
filegeonameID=${DIR_DATA}/geonameId-icao-correspondencia.txt
i=0
###loop over the METARs
for icao in $metarID; do
 # i=$(echo $i + 1 | bc)
  # imet=$(echo $i + 1 | bc)
  #geonameId=$(echo 899999999 - $imet | bc)
  geonameId=$(cat $filegeonameID | grep "$icao" | awk '{print $2}')
  lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []' )
  lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
  alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
#  temp=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .temp] | sort []')
#  last=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .last] | sort []')https://www.tiempo.com/mapas-meteorologicos/#

  #Download forecast at METAR location
  #curl http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o METAR-$icao.json

  curl 'http://aguila.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o ${DIR_DATA}/PREDIC-$icao.json

  cat ${DIR_DATA}/PREDIC-$icao.json  | jq '.dias[].horas[].utime' >pp1
  cat ${DIR_DATA}/PREDIC-$icao.json  | jq '.dias[].horas[].temperatura.valor' >pp2
  paste pp1 pp2 > ${DIR_DATA}/PREDIC-$icao.txt

  cp ${DIR_DATA}/PREDIC-$icao.txt kk-$icao

  metarfile="${DIR_DATA}/METAR-$icao.txt"
  nts=$(cat $metarfile | wc -l )
  for its in $(seq 1 $nts);do
     last=$(cat $metarfile | awk '{print $2}' | head -$its | tail -1)
     temp=$(cat $metarfile | awk '{print $3}' | head -$its | tail -1)

     fechaok=$(date --date=@$(echo $last/1000 | bc) '+%Y%m%d%H%M')

     #For METARs no o'clock data we look for the nearest unix time
     cat  ${DIR_DATA}/PREDIC-$icao.txt | awk '{print ($1 - '$last')*($1 - '$last')/2, $0,'$last','$temp',$2-'$temp','$fechaok'}' | sort -n | head -1  >> ${DIR_DATA}/PREDIC-METAR-$icao-$AAAAMMDDHH.txt
  done
#rm  METAR-$icao.txt PREDIC-$icao.txt pp* PREDIC-$icao.json
cat ${DIR_DATA}/PREDIC-METAR-$icao-$AAAAMMDDHH.txt | awk '{if ($6*$6/2 > 2 ) print "'$icao'",$0}' >> ${DIR_DATA}/DIFGT2-predic-metar-$AAAAMMDDHH.txt
cat ${DIR_DATA}/PREDIC-METAR-$icao-$AAAAMMDDHH.txt | awk '{print $6*$6/2, "'$icao'", "'$lon'", "'$lat'", $0}' | sort -rn | head -1 >> ${DIR_DATA}/DIFMAX-predic-metar-$AAAAMMDDHH.txt
Rscript --vanilla /home/raquel/repos/pruebas/METARs/plot-PREDICvsMETAR.R ${DIR_DATA}/PREDIC-METAR-$icao-$AAAAMMDDHH.txt ${DIR_PLOTS}/PREDIC-METAR-$icao-$AAAAMMDDHH.pdf $icao
done
#rm -f ${lockFile}
echo 'fin script predicciones'