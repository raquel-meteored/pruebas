#!/bin/bash
####################################################################################
### Validación de predicciones meteored con METARs
#   1. Descarga json con METARs info
#   2. Descarga json con predicciones METEORED del ECMWF en la localidad de los METARs
#   3. Datos en bruto del ECMWF en .txt descargados con get-info-ECMWF.sh
#   4. Compara temperaturas
#   5. Pinta series y mapa de sesgo con R
### RLP 11-2019. Ultima actualización: 01-2020
# Raquel Lorente Plazas <raquel@meteored.com>
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
filemetarID=/home/cep/METAR/meteoflight_reports.php #se descarga
if [[ -e ${filemetarID} ]] ; then
  rm -f $filemetarID
fi

#Comprobación de que existen los scripts
scriptR1=${DIR_BASE}/plot-PREDICvsMETAR.R
scriptR2=${DIR_BASE}/mapa-errores-METAR.R
#scriptECMWF=${DIR_BASE}/get-info-ECMWF.sh

if [[ ! -e $scriptR1 ]]; then
	echo "$(datePID): $scriptR1 no exite"
  exit 1;
fi
if [[ ! -e $scriptR2 ]]; then
	echo "$(datePID): $scriptR2 no exite"
  exit 1;
fi
#if [[ ! -e $scriptECMWF ]]; then
#	echo "$(datePID): $scriptECMWF no exite"
#  exit 1;
#fi


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
metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep '[L,E][A-Z][A-Z][A-Z]' | cut -c2-5)

#Truco de Juan para asegurarme que tengo t-odos los json descargados adecaudamente
ficherosdescargados=0
while [ ${ficherosdescargados} -eq 0 ]
do
  #loop sobre los METARs para descargar la predicción y comparar
  for icao in $metarID; do

    fnameMETAR=${DIR_DATA}/METAR-$icao-${dateDOWNLOAD}
    fnamePREDIC=${DIR_DATA}/PREDIC-$icao-${dateDOWNLOAD}
    fnameVALIDA=${DIR_DATA}/VALIDA-$icao-${weekDOWNLOAD}
    fnameECMWF=${DIR_DATA}/ECMWF-$icao-${weekDOWNLOAD} #creado con get-info-ECMWF.sh

    if [ ! -e "${fnamePREDIC}".json ]
    then
      echo "$(datePID): Ini descarga de json"
      ##Descarga METARs info (24h data) del json file
      curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o "$fnameMETAR".json
      ##Descarga forecast info del json file en la localidad del METAR
      lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
      lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
      alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
      echo "$(datePID): Fin descarga de json"

      if [ $? -eq 0 ]
      then
        #TODO no estoy usando fecha START ni fechaLEAD
	      ## Uso la fecha inicial del fichero para hacerme una idea del LEAD time
        #fechaSTART=$(jq '.dias[0].utime.start' $fnamePREDIC.json )
        #fechaSTARTok=$(date --date=@$(echo $fechaSTART/1000 | bc) '+%Y%m%d%H%M')

	      ##Para los METAR puede que haya pasos temporales sin datos de temp (con o sin NIL)
        fechasMETAR=$(jq '.metar_speci[].hour' ${fnameMETAR}.json)
        for idate in $fechasMETAR;do
          temp=$(jq '.metar_speci[] | select (.hour | contains('$idate')) | .report' ${fnameMETAR}.json | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]' | tr "M" "-" | cut -c1-3)
          if [ ! -z "$temp" ]
          then
            fechaMETAR=$idate
            fechaMETARok=$(date --date=@$(echo $fechaMETAR/1000 | bc) '+%Y%m%d%H%M')
            #fechaLEAD=$(echo '('$fechaMETAR' - '$fechaSTART') / 3600000' | bc ) #horas entre inicio de predic y METAR

            #Busco la predicción más cercana a la fecha del METAR
            fechaUP=$( echo $idate + 1800000 | bc)
            fechaDW=$( echo $idate - 1800000 | bc)
            fechaPRED=$(jq '.dias[].horas[] | select (.utime <= '$fechaUP' and .utime > '$fechaDW') | .utime' $fnamePREDIC.json)

            if [ ! -z "$fechaPRED" ] #puede ocurrir que la fecha del METAR no esté en el json de la predicc
            then
              fechaPREDok=$(date --date=@$(echo $fechaPRED/1000 | bc) '+%Y%m%d%H%M')
              fechaDIF=$(echo '('$fechaPRED' - '$fechaMETAR') / 60000 ' | bc ) # minutos
              tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
              #tempBIAS=$(echo $tempPRED - $temp | bc )

	            #Nos aseguramos que los datos se comparan con la última pasada
              if [ -e $fnameVALIDA.txt ]
              then
                mv  $fnameVALIDA.txt kkrmdate
                cat kkrmdate | awk 'NF==6' | grep -v $fechaMETAR  >  $fnameVALIDA.txt
                rm kkrmdate
              fi

              #Cogemos dato del ECMWF
              #TODO pasar awk a regular expression
              #tempECMWFp=$temp
              tempECMWFb=$(cat $fnameECMWF.txt | grep $fechaPREDok | awk '{print $2}')

              if [ ! -z "$tempECMWFb" ]
              then
                tempECMWF=$tempECMWFb
              else
                tempECMWF='NA'
              fi

 	            # Escribe datos en un archivo .txt para que pinte R
              echo "$fechaDIF" "$fechaPRED" "$tempPRED" "$fechaMETAR" "$temp" "$tempECMWF" >> "$fnameVALIDA".txt

            #else
            #  echo "$(datePID): WARNING'fechaPRED vacío' $icao $fechaPRED $fechaDW $fechaUP fechaMETAR' $fechaMETAR $fechaMETARok" >&2
            fi
          fi
        done
        echo "$(datePID): Ini plots w R $icao"

        #Nos aseguramos de que: 1) existe el archico y 2) tiene más de 1 fila y 3) todas las filas tienen NF columnas
        #TODO ver si eliminamos columnas. Ahora R sólo usa: $fechaPRED $tempPRED $fechaMETAR $temp
        filein=$fnameVALIDA.txt
        fileout=${DIR_DATA}/kkMEAN-BIAS-$icao-$weekDOWNLOAD.txt
        plotout=${DIR_PLOTS}/T-PREDIC-METAR-$icao-$weekDOWNLOAD.png

        if [ ! -e $filein ];
        then
          echo "$(datePID): No encontrado $filein"
          #No me salgo porque en otro paso temporal puede crearse
        else
          nrow=$(cat $filein | wc -l)
          ncol=$(awk '{print NF}' $filein | sort -nu) # -u remove repeat text/lines
          if [ $ncol -eq 6 ] && [ $nrow -gt 1 ];
          then
            Rscript --vanilla ${DIR_BASE}/plot-PREDICvsMETAR.R $filein $plotout $icao $lon $lat $fileout
            echo "$(datePID): Fin plots w R $icao"
          else
            echo "$(datePID): $icao nrow or ncol icorrecto"
          fi
        fi

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
  Rscript --vanilla $scriptR2 "$filein" $plotout

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
#$DIR_DATA/*.txt
rm -f "${lockFile}"
echo 'fin script predicciones'

