#!/bin/bash
####################################################################################
### Validación de predicciones meteored con METARs
### 1. Descarga METARs info y las predicciones del ECMWF en la localidad de los METARs
### 2. Compara temperaturas
### 3. Pinta series con R y mapa de sesgo
### RLP 11-2019
###################################################################################
# Nombre del script.
scriptName=$(basename "$0")

# Formato de fecha para el fichero .log.
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

# Comprobación de que existe software para optimizar.
#TODO solo dejo el nombre del software sin el path (diferencia entre command y which?)
software="Rscript pdfjoin"
which ${software} > /dev/null 2>&1 || { echo "$(datePID): ${software} no está instalado." && exit 1; }

#Comprobación de que existen los directorios
DIR_BASE=/home/cep/METAR
DIR_DATA=$DIR_BASE/data/VALIDACION
DIR_PLOTS=$DIR_DATA/PLOTS
mkdir -p ${DIR_DATA} ${DIR_PLOTS}

#Comprobación de que existen los Ficheros
filegeonameID=${DIR_BASE}/geonameId-icao-correspondencia.txt #uso este fichero para que gonameID siempre correspoda al mismo METAR
filemetarID=meteoflight_reports.php #se descarga
if [[ ! -e $filegeonameID ]]; then
	echo "$(datePID): $filegeonameID no exite"
  exit 1;
fi
if [[ -e ${filemetarID} ]] ; then
  rm -f $filemetarID
fi

#Comprobación de que existen los scripts
scriptR1=${DIR_BASE}/plot-PREDICvsMETAR.R
scriptR2=${DIR_BASE}/mapa-errores-METAR.R

if [[ ! -e $scriptR1 ]]; then
	echo "$(datePID): $scriptR1 no exite"
  exit 1;
fi
if [[ ! -e $scriptR2 ]]; then
	echo "$(datePID): $scriptR2 no exite"
  exit 1;
fi


#TODO ver si lockFile funciona
# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
lockFile=${DIR_DATA}/${scriptName}_${dateDOWNLOAD}.lock
if [[ -e ${lockFile} ]] ; then
  if [[ $(stat -c %Y "${lockFile}") -gt $(date -u +%s --date="180 minutes ago") ]] ; then
    echo "$(datePID): el fichero ${lockFile} es muy antiguo"
    exit 1;
  else
    touch "${lockFile}"
  fi
fi

#Fechas y limites temporales
dateDOWNLOAD=$(date -u +%Y%m%d%H%M)
#dateDOWNLOADu=$(date -u +%s000)
weekDOWNLOAD=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

###Descarga METARs info: lon lat alt (LE españoles)
echo "$(datePID): Inicia descarga de $filemetarID"
curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
echo "$(datePID): Fin descarga de $filemetarID"

metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)

#Truco de Juan para asegurarme que tengo t-odos los json descargados adecaudamente
ficherosdescargados=0
while [ ${ficherosdescargados} -eq 0 ]
do
  #loop sobre los METARs para descargar la predicción y comparar
  for icao in $metarID; do

    fnameMETAR=${DIR_DATA}/METAR-$icao-${dateDOWNLOAD}
    fnamePREDIC=${DIR_DATA}/PREDIC-$icao-${dateDOWNLOAD}
    fnameVALIDA=${DIR_DATA}/VALIDA-$icao-${weekDOWNLOAD}

    if [ ! -e "${fnamePREDIC}".json ]
    then
      echo "$(datePID): Ini descarga de json"
      ##Descarga METARs info (24h data) del json file
      curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o "$fnameMETAR".json
      ##Descarga forecast info del json file en la localidad del METAR

      geonameId=$(cat $filegeonameID | grep "$icao" | awk '{print $2}')
      lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
      lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
      alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
      echo "$(datePID): Fin descarga de json"

      if [ $? -eq 0 ]
      then
        #TODO no estoy usando fecha START ni fechaLEAD
	      ## Uso la fecha inicial del fichero para hacerme una idea del LEAD time
        #fechaSTART=$(cat $fnamePREDIC.json | jq '.dias[0].utime.start')
        #fechaSTARTok=$(date --date=@$(echo $fechaSTART/1000 | bc) '+%Y%m%d%H%M')

	      ##Para los METAR puede que haya pasos temporales sin datos de temp (con o sin NIL)
        fechasMETAR=$(jq '.metar_speci[].hour' ${fnameMETAR}.json)
        for idate in $fechasMETAR;do
          temp=$(jq '.metar_speci[] | select (.hour | contains('$idate')) | .report' ${fnameMETAR}.json | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]' | tr "M" "-" | cut -c1-3)
          if [ ! -z "$temp" ]
          then
            fechaMETAR=$idate
            fechaMETARok=$(date --date=@$(echo $fechaMETAR/1000 | bc) '+%Y%m%d%H%M')
            #Busco la predicción más cercana a la fecha del METAR
            fechaUP=$( echo $idate + 1800000 | bc)
            fechaDW=$( echo $idate - 1800000 | bc)
            fechaPRED=$(jq '.dias[].horas[] | select (.utime <= '$fechaUP' and .utime > '$fechaDW') | .utime' $fnamePREDIC.json)
            fechaDIF=$(echo '('$fechaPRED' - '$fechaMETAR') / 60000 ' | bc ) # minutos
            #fechaLEAD=$(echo '('$fechaMETAR' - '$fechaSTART') / 3600000' | bc ) #horas entre inicio de predic y METAR

            tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
            #tempBIAS=$(echo $tempPRED - $temp | bc )

	          #Nos aseguramos que los datos se comparan con la última pasada
            if [ -e $fnameVALIDA.txt ]
            then
              mv  $fnameVALIDA.txt kkrmdate
              cat kkrmdate | awk 'NF==6' | grep -v $fechaMETAR  >  $fnameVALIDA.txt
              rm kkrmdate
            fi
            # TODO simplificar, sobran columnas? NF
 	          # Escribe datos en un archivo .txt para que pinte R (5 columnas!)
 	          # R sólo va a usar $fechaPRED $tempPRED $fechaMETAR $temp
            echo "$fechaDIF" "$fechaPRED" "$tempPRED" "$fechaMETAR" "$temp" "$fechaMETARok" >> "$fnameVALIDA".txt
          fi

        done
        echo "$(datePID): Ini plots w R $icao"

        #warning: si se cambian los parámetros de entradas modificar R consecuentemente
        filein=$fnameVALIDA.txt
        fileout=${DIR_DATA}/kkMEAN-BIAS-$icao-$weekDOWNLOAD.txt
        plotout=${DIR_PLOTS}/T-PREDIC-METAR-$icao-$weekDOWNLOAD.png
        Rscript --vanilla ${DIR_BASE}/plot-PREDICvsMETAR.R $filein $plotout $icao $lon $lat $fileout
	      echo "$(datePID): Fin plots w R $icao"

      elif [ -e ${fnamePREDIC}.json ]
      then
        rm $fnamePREDIC.json
      fi
    fi
  done #end loop over icao

  cat  ${DIR_DATA}/kkMEAN-BIAS-*-$weekDOWNLOAD.txt > ${DIR_DATA}/MAPA-T-PREDIC-METAR-$weekDOWNLOAD.txt
  rm ${DIR_DATA}/kkMEAN-BIAS-*-$weekDOWNLOAD.txt

  #warning: si se cambian los parámetros de entradas modificar R consecuentemente
  filein=${DIR_DATA}/MAPA-T-PREDIC-METAR-$weekDOWNLOAD.txt
  plotout=${DIR_PLOTS}/MAPA-T-PREDIC-METAR-$weekDOWNLOAD.pdf
  Rscript --vanilla $scriptR2 "$filein"  $plotout

  ficherosdescargados=1
  for icao in $metarID; do
    if [ ! -e "$fnamePREDIC".json ]
    then
      ficherosdescargados=0;
      break;
    fi
  done
done

#FIXME buscar como pegar los png
#convert $DIR_DATA/PLOTS/*$weekDOWNLOAD.png $DIR_DATA/PLOTS/JOINED-T-PREDIC-METAR-$weekDOWNLOAD.png
#FIXME cuando vea que funciona, directamente borrar lo que hay en basura
mv $DIR_DATA/*.json ${DIR_DATA}/basura
rm -f "${lockFile}"
echo 'fin script predicciones'
