#!/bin/bash
#Lee temperatura de los METARs

########METARs (Meterologial Aviation Report) info is as follows:
#XXXX ICAO (International Civil Aviation Organization) airport code
#ddHHHHZ time of the observation. Day of the month and time of the day in UTC
#DIRWSMPS DIR wind irection in degrees and wind speed in m/s (if KT in knots)
#DIR1VDIR2 wind direction is varing form DIR1 to DIR2
#XXXX visibility in m
#RYY/PXXXXN Runway Visual Range for runway YY is XXXX m
#RYY/PXXXXU Runway Visual Range
#+SN snow (+ heavy -light)
#BKNXXX
#OVCXXX
#MXX/MYY XX temperatu in C and dew point in C. M=below zero
###########################################################

DIR_DATA=~/data/VALIDACION/
AAAAMMDDHH=$(date +%Y%m%d%H%M)
scriptName=$(basename $0 .sh)
weeknum=$(date '+%W')
lockFile=${DIR_DATA}/${scriptName}_${AAAAMMDDHH}.lock
filemetarID=meteoflight_reports.php

curl http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID

metarID=$(cat $filemetarID | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)

i=0
for icao in $metarID; do
  imet=$(echo $i + 1 | bc)
  geonameId=$(echo 999999999 - $imet | bc)
  #icao=$(cat $filemetarID | jq '.points['$imet'].icao' | cut -c2-5)
  lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []' )
  lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
  alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
  temp=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .temp] | sort []')
  last=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .last] | sort []')

  #curl http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o METAR-$icao.json
 # echo $icao $last $temp $lat $lon $alt  >> ${DIR_DATA}/METAR-$icao.txt
  echo $icao $last $temp $AAAAMMDDHH >> ${DIR_DATA}/METAR-$icao-$weeknum.txt
  mv $filemetarID > ${DIR_DATA}/basura/METAR-$icao-$AAAAMMDDHH.json
done
echo 'fin del metar'
