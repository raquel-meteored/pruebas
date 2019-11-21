#!/bin/bash
####################################################################################
### Descarga METARs info y las predicciones del ECMWF en la localidad de los METARs 
### Compara temperaturas
### Pinta series con R
### RLP 11-2019
###################################################################################
# Nombre del script.
scriptName=$(basename $0)

# Formato de fecha para el fichero .log.
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

# Comprobación de que existe software para optimizar.
Rscript="/usr/bin/Rscript"
command -v ${Rscript} > /dev/null 2>&1 || { echo "$(datePID): ${Rscript} no está instalado." && exit 1; }

#Fechas y limites temporales
dateDOWNLOAD=$(date -u +%Y%m%d%H%M)
dateDOWNLOADu=$(date -u +%s000)
weekDOWNLOAD=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#Directorios
DIR_BASE=/home/cep/METAR
DIR_DATA=$DIR_BASE/data/VALIDACION
DIR_PLOTS=$DIR_DATA/PLOTS

#Ficheros
filegeonameID=${DIR_BASE}/geonameId-icao-correspondencia.txt #uso este fichero para que gonameID siempre correspoda al mismo METAR
filemetarID=meteoflight_reports.php #se descarga

#Comprobación de que existen los directorios y ficheros
mkdir -p ${DIR_DATA} ${DIR_PLOTS}
if [[ ! -e $filegeonameID ]]; then
	echo "$(datePID): $filegeonameID no exite"
  exit 1;
fi

# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
#scriptName=$(basename $0 .sh)
#lockFile=${DIR_DATA}/${scriptName}_${dateDOWNLOAD}.lock
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

echo "$(datePID): Inicia descarga de $filemetarID"
curl -s http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
echo "$(datePID): Fin descarga de $filemetarID"
metarID=$(cat $filemetarID | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)

#Truco de Juan para asegurarme que tengo todos los json descargados adecaudamente
ficherosdescargados=0
while [ ${ficherosdescargados} -eq 0 ]
do
  #loop sobre los METARs para descargar la predicción y comparar
  for icao in $metarID; do

    fnameMETAR=${DIR_DATA}/METAR-$icao-${dateDOWNLOAD}
    fnamePREDIC=${DIR_DATA}/PREDIC-$icao-${dateDOWNLOAD}
    fnameVALIDA=${DIR_DATA}/VALIDA-$icao-${weekDOWNLOAD}

    if [ ! -e $fnamePREDIC.json ]
    then
      echo "$(datePID): Ini descarga de json"
      ##Descarga METARs info (24h data) del json file
      curl -s http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o $fnameMETAR.json
      ##Descarga forecast info del json file en la localidad del METAR
      geonameId=$(cat $filegeonameID | grep "$icao" | awk '{print $2}')
      lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
      lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
      alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
      echo "$(datePID): Fin descarga de json"
      if [ $? -eq 0 ]
      then

	      ## Uso la fecha inicial del fichero para hacerme una idea del LEAD time
        fechaSTART=$(cat $fnamePREDIC.json | jq '.dias[0].utime.start')
        fechaSTARTok=$(date --date=@$(echo $fechaSTART/1000 | bc) '+%Y%m%d%H%M')

	      ##Para los METAR puede que haya pasos temporales sin datos de temp
        fechasMETAR=$(jq '.metar_speci[].hour' ${fnameMETAR}.json)
        for idate in $fechasMETAR;do
          temp=$(jq '.metar_speci[] | select (.hour | contains('$idate')) | .report' ${fnameMETAR}.json | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]' | tr "M" "-" | cut -c1-3)
          if [ ! -z "$temp" ]
          then
            fechaMETAR=$idate
            fechaMETARok=$(date --date=@$(echo $fechaMETAR/1000 | bc) '+%Y%m%d%H%M')
            fechaUP=$( echo $idate + 1800000 | bc)
            fechaDW=$( echo $idate - 1800000 | bc)
            fechaPRED=$(jq '.dias[].horas[] | select (.utime <= '$fechaUP' and .utime > '$fechaDW') | .utime' $fnamePREDIC.json)
            fechaDIF=$(echo '('$fechaPRED' - '$fechaMETAR') / 60000 ' | bc ) # minutos
            fechaLEAD=$(echo '('$fechaMETAR' - '$fechaSTART') / 3600000' | bc ) #horas entre inicio de predic y METAR

            tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
            tempBIAS=$(echo $tempPRED - $temp | bc )
           #echo $fechaDIF $fechaPRED $tempPRED $fechaMETAR $temp $tempBIAS $fechaMETARok $fechaSTARTok $fechaLEAD $icao
           # echo $tempPRED $fechaUP $fechaDW $fechaPRED

	          #Nos aseguramos que los datos se comparan con la última pasada
            if [ -e $fnameVALIDA.txt ]
            then
              mv  $fnameVALIDA.txt kkrmdate
              grep -v "'$fechaMETARok'" kkrmdate >  $fnameVALIDA.txt
            fi
 	          # Escribe datos en un archivo .txt para que pinte R
            echo $fechaDIF $fechaPRED $tempPRED $fechaMETAR $temp $tempBIAS $fechaMETARok $fechaSTARTok $fechaLEAD $icao >> $fnameVALIDA.txt
            echo $fechaDIF $fechaPRED $tempPRED $fechaMETAR $temp $tempBIAS $fechaMETARok $fechaSTARTok $fechaLEAD $icao >> kkvalida
          fi

        done

        echo "$(datePID): Ini plots w R $icao"
        Rscript --vanilla ${DIR_BASE}/plot-PREDICvsMETAR.R $fnameVALIDA.txt ${DIR_PLOTS}/T-PREDIC-METAR-$icao-$weekDOWNLOAD.pdf $icao $fechaSTART ${DIR_DATA}/MEAN-BIAS-$icao-$weekDOWNLOAD.txt
	      echo "$(datePID): Fin plots w R $icao"

        cat $fnameVALIDA.txt | awk '{if (sqrt($6*$6) > 2 ) print "'$icao'",$0,'$fechaLEAD'}' >> ${DIR_DATA}/DIFGT2-predic-metar-$weekDOWNLOAD.txt
        cat $fnameVALIDA.txt | awk '{print sqrt($6*$6), "'$icao'", "'$lon'", "'$lat'", $0,'$fechaLEAD'}' | sort -rn | head -1 >> ${DIR_DATA}/DIFMAX-predic-metar-$weekDOWNLOAD.txt

      elif [ -e $fnamePRECIC.json ]
      then
        rm $fnamePREDIC.json
      fi
    fi
  done #end loop over icao

  ficherosdescargados=1
  for icao in $metarID; do
    if [ ! -e $fnamePREDIC.json ]
    then
      ficherosdescargados=0;
      break;
    fi
  done
done

#rm -f ${lockFile}
pdfjoin  $DIR_DATA/PLOTS/*$weekDOWNLOAD.pdf 
mv *-joined.pdf $DIR_DATA/PLOTS
mv $DIR_DATA/*.json ${DIR_DATA}/basura
echo 'fin script predicciones'
