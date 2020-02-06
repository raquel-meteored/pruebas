#!/bin/bash
####################################################################################
### Validación de predicciones meteored con METARs
#   1. Descarga la info de los METARs de la web de guillermo
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
#DIR_BASE=/home/cep/METAR
DIR_BASE=/home/raquel/repos/pruebas/METAR
DIR_DATA=$DIR_BASE/DATA
DIR_PLOTS=$DIR_BASE/PLOT
mkdir -p ${DIR_DATA} ${DIR_PLOTS}

#Comprobación de que existen los Ficheros
# y si exiten se borran
filemetarID=$DIR_BASE/meteoflight_reports.php #se descarga
fnameMETAR=$DIR_BASE/metar.csv
if [[ -e ${filemetarID} ]] ; then
  rm -f $filemetarID
fi
if [[ -e ${fnameMETAR} ]] ; then
  rm -f $fnameMETAR
fi

#Comprobación de que existen los scripts
scriptR1=${DIR_BASE}/mapa-errores-METAR.R
if [[ ! -e $scriptR1 ]]; then
	echo "$(datePID): $scriptR1 no exite"
  exit 1;
fi

#Fechas y limites temporales
fechafin=$(echo $(date -u +%Y%m%d%H))
fechaini=$(echo $(date -u +%Y%m%d%H -d "-1 day"))
# Valores por defecto.
cc="A1"
S="D" # modelo determinista
DATE=$(date -u +%Y%m%d)
MMDDHHII="$(date -u +%m%d)${RUN}00"
dateDOWNLOAD=$fechafin
weekDOWNLOAD=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

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



##Descarga METARs coord: lon lat alt
echo "$(datePID): Inicia descarga de METAR"
curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
##Descarga METAR info
curl -s -m $LIM --connect-timeout $TIMEOUT "http://www.ogimet.com/cgi-bin/getmetar?begin=${fechaini}00&end=${fechafin}00" -o $fnameMETAR
echo "$(datePID): Fin descarga de METAR"
metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep '[L,E][A-Z][A-Z][A-Z]' | cut -c2-5)
#Truco de Juan para asegurarme que tengo t-odos los json descargados adecaudamente

#loop sobre los METARs para descargar la predicción y comparar
for icao in $metarID; do
    fnamePREDIC=${DIR_DATA}/PREDIC-$icao-$fechaini-$fechafin
    fnameVALIDA=${DIR_DATA}/VALIDA-$icao-$fechaini-$fechafin
    fnameECMWF=${DIR_DATA}/ECMWF-$icao-${weekDOWNLOAD} #creado con get-info-ECMWF.sh

      echo "$(datePID): Ini descarga de json"
      ##Descarga forecast info del json file en la localidad del METAR
      lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
      lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
      alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
      echo "$(datePID): Fin descarga de json"
      cat $fnameMETAR | grep "${icao}" | grep '[ M][0-9][0-9]/[M]*[0-9][0-9]' > kk$icao
      tempSUM=0
      while IFS=, read -r metar YYYY MM DD HH mm infoMETAR
      do
        fechaMETAR=$(date -d "${YYYY}/${MM}/${DD}H${HH}:${mm}" "+%s")
        fechaMETARok=$(echo "${YYYY}${MM}${DD}${HH}${mm}")

        #Busco la predicción más cercana a la fecha del METAR
        fechaUP=$( echo "${fechaMETAR}"*1000 + 1800000 | bc)
        fechaDW=$( echo "${fechaMETAR}"*1000 - 1800000 | bc)
        fechaPRED=$(jq '.dias[].horas[] | select (.utime <= '$fechaUP' and .utime > '$fechaDW') | .utime' $fnamePREDIC.json)
        if [ ! -z "$fechaPRED" ] #puede ocurrir que la fecha del METAR no esté en el json de la predicc
        then
          tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
          #tempMETAR=$(echo $infoMETAR | grep "${icao}" | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]' | tr "M" "-" | cut -c1-3)
          tempMETAR=$(echo $infoMETAR | grep "${metar}" | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]'| tr "M" "-" | tr "/" " " | awk '{print $1}')

          #Nos aseguramos que los datos se comparan con la última pasada
          if [ -e $fnameVALIDA.txt ]
          then
            mv  $fnameVALIDA.txt kkrmdate
            cat kkrmdate | awk 'NF==8' | grep -v $fechaMETAR  >  $fnameVALIDA.txt
            rm kkrmdate
          fi
        fi
        #TODO incluir datos del ECMWF
        tempECMWF="NAN"
        tempBIAS=$(echo $tempPRED - $tempMETAR | bc)
        tempSUM=$(echo $tempSUM + $tempBIAS | bc)
        # Escribe datos en un archivo .txt para que pinte R
        echo "$fechaMETARok" "$fechaPRED" "$tempPRED" "$fechaMETAR" "${tempMETAR}" "$tempECMWF" "$tempBIAS" "$tempSUM" >> ${fnameVALIDA}.txt
      done<kk$icao
      valida=$(cat -n ${fnameVALIDA}.txt | tail -1)
      echo "${icao}" "$lon" "$lat" "$alt" $valida | awk '{print $1,$2,$3,$12/$5,$13}' | awk 'NF==5' >> ${DIR_BASE}/VALIDA-mundo-$fechaini-$fechafin.txt
      rm $fnamePREDIC.json kk$icao
done #loop del icao

  #warning: si se cambian los parámetros de entradas modificar R consecuentemente
  filein=${DIR_BASE}/VALIDA-mundo-$fechaini-$fechafin.txt
  plotout=${DIR_PLOTS}/MAPA-mundo-METAR-$fechaini-$fechafin.pdf
  Rscript --vanilla $scriptR1 "$filein" "$plotout"

 # rm $fnameMETAR $filemetarID
