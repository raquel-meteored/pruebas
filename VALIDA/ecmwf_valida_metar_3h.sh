#!/bin/bash
####################################################################################
### Validación de predicciones meteored con METARs
#   1. Descarga la info de los METARs de la web de guillermo en un csv
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
software="Rscript"
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
DIR_DATA=/home/raquel/Data/METAR
DIR_PLOTS=/home/raquel/Plots
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

# Valores por defecto.
cc="A1"
S="D" # modelo determinista
fechafin=$(date -u +%Y%m%d%H)
fechaini=$(date -u +%Y%m%d%H -d "-12 hours")
DATE=$(date -u +%Y%m%d)
MMDDHHII="$(date -u +%m%d)${RUN}00"

LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
lockFile=${DIR_BASE}/${scriptName}_${fechafin}.lock
finishedFile=${DIR_BASE}/${scriptName}_${fechafin}.finished
# Si existe el fichero de bloqueo y tiene menos de X minutos termina.
if test -e "${lockFile}" ; then
  if test $(stat -c %Y "${lockFile}") -lt $(date -u +%s --date="20 minutes ago") ; then
    echo -n "[$(date -u +%y%m%d_%H:%M:%S) UTC] (PID $$) - "
    echo "Archivo de bloqueo demasiado antiguo. Borrando y creando..."
    touch "${lockFile}"
  else
    echo -n "[$(date -u +%y%m%d_%H:%M:%S) UTC]                "
    echo "(PID $$) - Archivo de bloqueo existente. Saliendo..."
    exit
  fi
else
  echo "[$(date -u +%y%m%d_%H:%M:%S) UTC] (PID $$) - Inicio"
  touch "${lockFile}"
fi

#condicion=true
#if [ "$condicion" == true ]; then
##Descarga METARs coord: lon lat alt
echo "$(datePID): Inicia descarga de METAR"
curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
##Descarga METAR info
curl -s -m $LIM --connect-timeout $TIMEOUT "http://www.ogimet.com/cgi-bin/getmetar?begin=${fechaini}00&end=${fechafin}00" -o $fnameMETAR

metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep '[A-Z][A-Z][A-Z][A-Z]' | cut -c2-5)

echo "$(datePID): Fin descarga de METAR"

#Sólo cojo las primeras 12 h
proy_HRES=$(seq --format %03g 0 3 13)
proy=(${proy_HRES[@]})
#loop sobre los METARs para descargar la predicción y comparar
for icao in $metarID; do
  fnamePREDIC=${DIR_DATA}/PREDIC-$icao-$fechaini-$fechafin
  fnameVALIDA=${DIR_DATA}/VALIDA-$icao-$DATE
  fnameECMWF=${DIR_DATA}/ECMWF-$icao-$fechaini-$fechafin #creado con get-info-ECMWF.sh

  echo "$(datePID): Ini descarga de json"
  ##Descarga forecast info del json file en la localidad del METAR
  lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
  lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
  alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')
  curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
  echo "$(datePID): Fin descarga de json"

  for ((i=0; i<${#proy[@]}; i++)) ; do
    # Caso de fichero de análisis.
    if [[ $(( 10#${proy[$i]} )) -eq 0 ]] ; then
      mmddhhii="$(date -u +%m%d%H%M --date="${DATE} ${RUN} 1 minute")"
     # Resto de casos.
    else
      mmddhhii="$(date -u +%m%d%H%M --date="${DATE} ${RUN} $(( 10#${proy[$i]} )) hours")"
    fi
    #Grib con datos del ECMWF en bruto
    grib=/home/ecmwf/${cc}${S}${MMDDHHII}${mmddhhii}1
    if [[ -f ${grib} ]]; then
        echo "$(datePID) extrayendo info de ${grib} para $icao"
        #Sacamos el punto más cercano
        temp2t=($(${path_software} -l ${lat},${lon},1 -w shortName=2t -p date,step ${grib}))
        tempECMWF=$(echo ${temp2t[2]} - 273.15 | bc )
        paso=$(echo   "${temp2t[1]}" +  "${RUN}" | bc)
        fechaECMWF=$(echo  "${temp2t[0]}"*10000 +  "${paso}"*100 | bc)
        YYYY=$(echo $fechaECMWF | cut -c1-4)
        MM=$(echo $fechaECMWF | cut -c5-6)
        DD=$(echo $fechaECMWF | cut -c7-8)
        HH=$(echo $fechaECMWF | cut -c9-10)
        mm=$(echo $fechaECMWF | cut -c11-12)
        fechaPRED=$( echo $(date -d "${YYYY}/${MM}/${DD}H${HH}:${mm}" "+%s")*1000 | bc )
        tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
        cat "$fnameMETAR" | tr "," " "| awk '{if ($1=="'$icao'" && $2=='$YYYY' && $3=='$MM' && $4=='$DD' && $5=='$HH') print $0}' | head -1 >  kk
        tempMETAR=$(cat kk | grep "${icao}" | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]'| tr "M" "-" | tr "/" " " | awk '{print $1}')
        fechaMETAR=$(cat kk | awk '{print $2$3$4$5$6}')
        echo $fechaMETAR

        if [ -z "$fechaMETAR" ]; then
          tempMETAR='NAN'
          fechaMETAR='NAN'
          tempBIAS='NAN'
          tempRMSE='NAN'
        else
          tempBIAS=$(echo "${tempPRED}" - "${tempMETAR}" | bc)
          tempBIAS_ECMWF=$(echo "${tempECMWF}" - "${tempMETAR}" | bc)
          tempRMSE=$(echo ${tempBIAS}^2 | bc)
          tempRMSE_ECMWF=$(echo ${tempBIAS_ECMWF}^2 | bc)
        fi

        if [ -e $fnameVALIDA.txt ]; then
            mv  $fnameVALIDA.txt kkrmdate
            cat kkrmdate | awk 'NF==10' | grep -v $fechaECMWF  >  $fnameVALIDA.txt
            rm kkrmdate
        fi

        echo "${fechaMETAR}" "$tempMETAR" "$fechaPRED" "$tempPRED" "$fechaECMWF" "$tempECMWF" "$tempBIAS"  "$tempBIAS_ECMWF" "$tempRMSE" "$tempRMSE_ECMWF" >> ${fnameVALIDA}.txt
    else
      echo "$(datePID): No existe el grib file"
      exit
    fi
  done #loop fechas
      echo "$(datePID): Fin parseo fechas del $icao"
      #TODO división
      #valida=$(cat -n ${fnameVALIDA}.txt | grep -v "NAN" | tail -1)
      bias=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$7}END{print s}' )
      rmse=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$9}END{print s}')
      rmseECMWF=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$10}END{print s}')
      tempMETAR=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$6}END{print s}')
      tempECMWF=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$2}END{print s}')
      tempPRED=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$4}END{print s}')
      npasos=$(cat ${fnameVALIDA}.txt | grep -v "NAN"| wc -l )
      echo "${icao}" "$lon" "$lat" "$bias" "$rmse" "${rmseECMWF}" "${tempMETAR}" "${tempPRED}" | awk '{print $1,$2,$3,$4/'$npasos',sqrt($5/'$npasos'),sqrt($6/'$npasos'),$7/'$npasos', $8/'$npasos'}' | awk 'NF==8' >> ${DIR_DATA}/VALIDA-mundo-${DATE}.txt
      echo $npasos
      rm $fnamePREDIC.json
done #loop del icao
echo "$(datePID): Fin parseo loop ICAO"

#fi #TODO quitar condicional cuando fuencione
#warning: si se cambian los parámetros de entradas modificar R consecuentemente
filein=${DIR_DATA}/VALIDA-mundo-$DATE.txt
plotMundo=${DIR_PLOTS}/MAPA-mundo-METAR-$DATE.pdf
plotEuropa=${DIR_PLOTS}/MAPA-Europa-METAR-$DATE.pdf
plotEEUU=${DIR_PLOTS}/MAPA-EEUU-METAR-$DATE.pdf
plotTemp=${DIR_PLOTS}/MAPA-temp-METAR-$DATE.pdf
plotMeteored=${DIR_PLOTS}/MAPA-temp-Meteored-$DATE.pdf

R --slave --args "${filein}" "${plotMundo}" "${plotEuropa}" "${plotEEUU}" "${plotTemp}" "${plotMeteored}"<< EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)
  library("maps")
  library("mapdata")
  library("mapproj")
 #library(ggmap)

  valida=read.table(args[1])
  data=data.frame(lon=valida[,2],lat=valida[,3],bias=valida[,4], rmse=valida[,5], rmseECMWF=valida[,6], temp=valida[,7], tempMeteored=valida[,8], icao=valida[,1])
  spainMap <- map_data("world")

  pdf(args[2])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmse, fill=bias), shape=21, col="black") +
	      # geom_point(data=data, aes(x=lon, y=lat, size=rmseECMWF), shape=5, col="black") +
	       #geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
        # coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-10,10))+
        # scale_shape_manual(values=c(21,5),labels=c("meteored","ecmwf"))+
         labs(title="Validación: METAR vs METEORED predicciones", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[3])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmse, fill=bias), shape=21, col="black") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmseECMWF), shape=5, col="black") +
	       #geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-10,10))+
         labs(title="Validación: METAR vs METEORED predicciones", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[4])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmse, fill=bias), shape=21, col="black") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmseECMWF), shape=5, col="black") +
	       #geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
         coord_map("lambert",lat0=0,lat1=45,xlim=c(-150,-50), ylim=c(22,55))+
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-10,10))+
         labs(title="Validación: METAR vs METEORED predicciones", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[5])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=.6, fill=temp), shape=21, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-35,35))+
         labs(title="Validación: Temperaturas METAR", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[6])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=.6, fill=tempMeteored), shape=21, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-35,35))+
         labs(title="Validación: Temperaturas Meteored", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

EOF
echo "$(datePID):Fin pintar mapa"
rm $fnameMETAR $filemetarID

# Se borra fichero de bloqueo y se crea fichero de finalización.
rm ${lockFile}
touch ${finishedFile}
echo "[`date -u +%y%m%d_%H%M%S` UTC] (PID $$) - Fin"
