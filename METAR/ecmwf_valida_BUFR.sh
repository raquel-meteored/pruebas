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
software="Rscript"
which ${software} > /dev/null 2>&1 || { echo "$(datePID): ${software} no está instalado." && exit 1; }
path_software="/usr/local/bin/"

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

echo "$(datePID): Inicia descarga de BUFR"
#centro="LEMM LFPW ETGT"
centro="LEMM"
tipo=IS

# Valores por defecto.
cc="A1"
S="D" # modelo determinista
fechafin="$(date -u +%Y%m%d%H)"00
fechaini="$(date -u +%Y%m%d%H -d "-12 hours")"00
DATE=$(date -u +%Y%m%d)
MMDDHHII="$(date -u +%m%d)${RUN}00"

DIR_DATA=/home/raquel/Data/BUFR
DIR_PLOTS=/home/raquel/Plots/BUFR
fnameBUFR=${DIR_DATA}/BUFR-temp-${fechaini}-${fechafin}.txt
dirBUFR=/home/raquel/Data/BUFR

LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#################### EXTRACCIÓN BUFR DATOS ###########################
#Edita archivo para filtro BUFR
{
  echo "set unpack=1;"
  echo "if (defined(airTemperature)) {"
  echo "print \"DATA,[/subsetNumber=XX/stationNumber],[/subsetNumber=XX/year],[/subsetNumber=XX/month%02d],[/subsetNumber=XX/day%02d],[/subsetNumber=XX/hour%02d],[/subsetNumber=XX/minute],[/subsetNumber=XX/airTemperature%.4f],[/subsetNumber=XX/longitude],[/subsetNumber=XX/latitude]\";"
  echo "print \"STATION,[/subsetNumber=XX/stationNumber],[/subsetNumber=XX/longitude],[/subsetNumber=XX/latitude],[/subsetNumber=XX/heightOfStationGroundAboveMeanSeaLevel],[/subsetNumber=XX/stationOrSiteName] \";"
#  echo "transient tK = airTemperature - 273 ;" no logro que lo reste a todos los subsets
  echo "}"
  #write;
} > filter_file_temp

#Sacamos los datos de los BUFR. Creamos un csv con datos y otro con la info de la estación
for ecenter in ${centro};do
  curl -s -m $LIM --connect-timeout $TIMEOUT "http://www.ogimet.com/getbufr.php?res=tar&beg="${fechaini}"&end=${fechafin}&ecenter="${ecenter}"&type=${tipo}" -o "${DIR_DATA}"/BUFR.tar
  mkdir "${DIR_DATA}"/BUFR_temp_"$ecenter"
  tar -xvf "${DIR_DATA}"/BUFR.tar -C "${DIR_DATA}"/BUFR_temp_"${ecenter}"
  for file_BUFR in $(ls "${DIR_DATA}"/BUFR_temp_"${ecenter}"/*_"${ecenter}"_*00.bufr );do
    nsubset=$(bufr_get -p numberOfSubsets ${file_BUFR})
  #  nsubset=2
    for isubset in $(seq 1 "${nsubset}");do
    ##bufr_dump -Dfilter ${file_BUFR} > filter_file
    cat filter_file_temp | sed 's/XX/'${isubset}'/g' > filter_file
    bufr_filter filter_file ${file_BUFR} | grep "DATA" | grep -v "MISSING" | awk -F',' '{if ($8>0) print $0}' >> filter.out.data
    bufr_filter filter_file ${file_BUFR} | grep "STATION" | grep -v "MISSING" | grep -v "Coincidencia"  >>  filter.out.station
    done
  done

mv filter.out.data $fnameBUFR
mv filter.out.station ${DIR_DATA}/BUFR-STATION.csv
#cat ${DIR_DATA}/BUFR-STATION.csv | head -20 > kkbufr
done #loop sobre ecenter
################ FIN EXTRACCIÓN BUFR ###############################################

############# VALIDACIÓN DE LAS PREDICCIONES #######################################
#Sólo cojo las primeras 12 h
proy_HRES=$(seq --format %03g 0 3 13)
proy=(${proy_HRES[@]})

#loop sobre los BUFRs para descargar la predicción y comparar

while IFS=, read -r station station_number lon lat alt name
do
fnamePREDIC=${DIR_DATA}/PREDIC-${station_number}-$fechaini-$fechafin
fnameVALIDA=${DIR_DATA}/VALIDA-BUFR-${station_number}-$fechaini-$fechafin
  if [ ! -f $fnamePREDIC.json ]; then
    echo "Descarga json predicciones"
    curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='${station_number}'' -o $fnamePREDIC.json
  fi

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
      temp2t=($("${path_software}"/grib_get -l ${lat},${lon},1 -w shortName=2t -p date,step ${grib})) #no quitar paréntesis, es un vector
      tempECMWF=$(echo ${temp2t[2]} - 273.15 | bc )
      paso=$(echo   "${temp2t[1]}" +  "${RUN}" | bc)
      fechaECMWF=$(echo  "${temp2t[0]}"*10000 +  "${paso}"*100 | bc)
      YYYY=$(echo $fechaECMWF | cut -c1-4)
      MM=$(echo $fechaECMWF | cut -c5-6)
      DD=$(echo $fechaECMWF | cut -c7-8)
      HH=$(echo $fechaECMWF | cut -c9-10)
      mm=$(echo $fechaECMWF | cut -c11-12)
      #fechaECMWF=$(echo $(date -d "${YYYY}/${MM}/${DD}H${HH}:${mm}" "+%s")*1000 | bc )
      fechaPRED=$(echo $(date -d "${YYYY}/${MM}/${DD}H${HH}:${mm}" "+%s")*1000 | bc )
      tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC.json)
      tempBUFR=$(cat "$fnameBUFR" | awk -F',' '{if ($2=="'${station_number}'" && $3=='$YYYY' && $4=='$MM' && $5=='$DD' && $6=='$HH') print $8-273.15}' | head -1)
      fechaBUFR=$(cat "$fnameBUFR" | awk -F',' '{if ($2=="'${station_number}'") print $3}' | head -1)

      if [ -z "$fechaBUFR" ]; then
        tempBUFR='NAN'
        fechaBUFR='NAN'
        tempBIAS='NAN'
        tempRMSE='NAN'
        tempBIAS_ECMWF='NAN'
        tempRMSE_ECMWF='NAN'
      else
        tempBIAS=$(echo "${tempPRED}" - "${tempBUFR}" | bc)
        tempBIAS_ECMWF=$(echo "${tempECMWF}" - "${tempBUFR}" | bc)
        tempRMSE=$(echo ${tempBIAS}^2 | bc)
        tempRMSE_ECMWF=$(echo ${tempBIAS_ECMWF}^2 | bc)
      fi

      if [ -e $fnameVALIDA.txt ]; then
        mv  $fnameVALIDA.txt kkrmdate
        cat kkrmdate | awk 'NF==10' | grep -v $fechaECMWF  >  $fnameVALIDA.txt
        rm kkrmdate
      fi
    else
      echo "$(datePID): No existe el grib file"
      exit
    fi
    echo "${fechaBUFR}" "${tempBUFR}" "$fechaPRED" "$tempPRED" "$fechaECMWF" "$tempECMWF" "$tempBIAS"  "$tempBIAS_ECMWF" "$tempRMSE" "$tempRMSE_ECMWF" >> ${fnameVALIDA}.txt
    done #loop fechas
    #TODO división
    #valida=$(cat -n ${fnameVALIDA}.txt | grep -v "NAN" | tail -1)
    bias=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$7}END{print s}' )
    rmse=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$9}END{print s}')
    rmseECMWF=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$10}END{print s}')
    tempBUFR=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$6}END{print s}')
    tempECMWF=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$2}END{print s}')
    tempPRED=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | awk '{s+=$4}END{print s}')
    npasos=$(cat ${fnameVALIDA}.txt | grep -v "NAN"| wc -l )
    echo "${station_number}" "$lon" "$lat" "$bias" "$rmse" "${rmseECMWF}" "${tempBUFR}" "${tempPRED}" | awk '{print $1,$2,$3,$4/'$npasos',sqrt($5/'$npasos'),sqrt($6/'$npasos'),$7/'$npasos', $8/'$npasos'}' | awk 'NF==8' >> ${DIR_DATA}/VALIDA-BUFR-mundo-$DATE.txt
    echo $npasos
#done < kkbufr
done < ${DIR_DATA}/BUFR-STATION.csv

############## FIN VALIDACIÓN ###############################################

############### PINTAR MAPAS #######################################

filein=${DIR_DATA}/VALIDA-BUFR-mundo-${DATE}.txt
plotTemp=${DIR_PLOTS}/BUFR-temp.pdf
plotBias=${DIR_PLOTS}/BUFR-bias.pdf
R --slave --args "${filein}"  "${plotTemp}" "${plotBias}"<< EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)
  library("maps")
  library("mapdata")
  library("mapproj")
 #library(ggmap)

  valida=read.table(args[1])
  data=data.frame(lon=valida[,2],lat=valida[,3], temp=valida[,7], bias=valida[,4], rmse=valida[,5])
  spainMap <- map_data("world")

  pdf(args[2])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=.05, fill=temp), shape=21, col="black") +
	       coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-35,35))+
         labs(title="Validación: Temperaturas BUFR", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[3])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, size=rmse, fill=bias), shape=21, col="black") +
	     #  geom_point(data=data, aes(x=lon, y=lat, size=rmseECMWF), shape=5, col="black") +
	       #geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-10,10))+
         labs(title="Validación: BUFR vs METEORED predicciones", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

EOF
rm $DIR_DATA/*.json
#echo "$(datePID):Fin pintar mapa"
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][1][1][6][2][1].key >> kkinfo$centro
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][1][1][6][2][1].value
#latitude
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][0].key
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][0].value
#longitude
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][0].key
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][0].value
#heightOfStationGroundAboveMeanSeaLevel
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][1][0].key
#bufr_dump -ja ${file} | jq .messages[0][22][0][2][1][1][1][1][1][1][1][1][1][1][0].value