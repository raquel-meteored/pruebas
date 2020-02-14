#!/bin/bash
####################################################################################
### Validación de predicciones meteored con METARs
#   1. Descarga la info de los METARs de la web de guillermo en un cvs
#   2. Descarga json con predicciones METEORED del ECMWF en la localidad de los METARs
#   3. Datos en bruto del ECMWF en .txt descargados con get-info-ECMWF.sh
#   4. Compara temperaturas
#   5. Pinta series y mapa de sesgo con R
### Creado en 02-2020
# Raquel Lorente Plazas <raquel@meteored.com>
# Marcos Molina Cano <marcos@meteored.com>
# Juan Sanchez Segura <jsanchez@meteored.com>
# Guillermo Ballester Valor <gbv@ogimet.com>
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
path_software="/usr/local/bin/grib_get"

# Función que muestra la ayuda.
function showUsage() {
  echo
  echo "Uso: ${scriptName} 00|12  [-h|--help]"
  echo "        00|12 - Hora de inicio de la pasada."
  echo "        [-h|--help] - Se muestra esta ayuda."
  echo
}

# Control de los argumentos imprescindibles.
if [[ $# -eq 0 ]] ; then
  showUsage
  exit 1

elif [[ $# -gt 0 ]] ; then

  if [[ "$1" == "00" ]] || [[ "$1" == "12" ]] ; then
    RUN="$1"
  else
    showUsage
    exit 1
  fi
fi


#Comprobación de que existen los directorios
#DIR_BASE=/home/cep/METAR
DIR_BASE=/home/raquel/repos/pruebas/METAR
DIR_DATA=$DIR_BASE/DATA
DIR_PLOTS=$DIR_BASE/PLOTS
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
fechafin=$(date -u +%Y%m%d%H)
fechaini=$(date -u +%Y%m%d%H -d "-12 hours")
echo $fechaini

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

metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep '[K][A-Z][A-Z][A-Z]' | cut -c2-5)

echo $metarID > ppMETARs
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
      tempSUMBIAS=0
      tempSUMRMSE=0
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
          #mmddhhii=
          #grib=/home/ecmwf/${cc}${S}${MMDDHHII}${mmddhhii}1
          #if [ -e $grib ]
          #then
          #  else
          #    tempECMWF='NAN'
          #fi
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
        tempRMSE=$(echo ${tempBIAS}*${tempBIAS}  | bc)

        tempSUMBIAS=$(echo $tempSUMBIAS + $tempBIAS | bc)
        tempSUMRMSE=$(echo $tempSUMRMSE + $tempRMSE | bc)

        # Escribe datos en un archivo .txt para que pinte R
        echo "$fechaMETARok" "$fechaPRED" "$tempPRED" "$fechaMETAR" "${tempMETAR}" "$tempECMWF" "$tempSUMBIAS" "$tempSUMRMSE" >> ${fnameVALIDA}.txt
      done<kk$icao
      echo "$(datePID):Fin parseo fechas del $icao"
      valida=$(cat -n ${fnameVALIDA}.txt | tail -1)
      echo "${icao}" "$lon" "$lat" "$alt" $valida | awk '{print $1,$2,$3,$12/$5,sqrt($13)/$5}' | awk 'NF==5' >> ${DIR_BASE}/VALIDA-mundo-$fechaini-$fechafin.txt
      rm $fnamePREDIC.json kk$icao
done #loop del icao
echo "$(datePID):Fin parseo loop ICAO"
  #warning: si se cambian los parámetros de entradas modificar R consecuentemente
  filein=${DIR_BASE}/VALIDA-mundo-$fechaini-$fechafin.txt
  plotout=${DIR_PLOTS}/MAPA-mundo-METAR-$fechaini-$fechafin.pdf

R --slave --args "${filein}" "${plotout}" << EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)
  library("maps")
  library("mapdata")
  library("mapproj")
 #library(ggmap)

  valida=read.table(args[1])
  data=data.frame(lon=valida[,2],lat=valida[,3],bias=valida[,4], rmse=valida[,5], icao=valida[,1])
  spainMap <- map_data("world")

  pdf(args[2])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="black") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmse, color=bias)) +
	       #geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
         #coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
         scale_color_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3")+
         labs(title="Validación: METAR vs METEORED predicciones", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
            panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))
EOF
echo "$(datePID):Fin pintar mapa"
#  Rscript --vanilla $scriptR1 "$filein" "$plotout"

 # rm $fnameMETAR $filemetarID
echo "Fin descarga ecmwf data"
rm ${lockFile}