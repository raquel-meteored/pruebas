#!/bin/bash
####################################################################################
### Validación de predicciones meteored con los SYNOP de los BUFR
#   1. Descarga la info de los BUFRs de la web de guillermo
#   2. Descarga json con predicciones METEORED del ECMWF en la localidad de los BUFR
#   3. Datos en bruto del ECMWF de los grb
#   4. Compara preicp
#   5. Pinta mapa de sesgo con R
### Creado en 05-2020
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
fechafin="$(date -u +%Y%m%d%H)"00
fechaini="$(date -u +%Y%m%d%H -d "-12 hours")"00
DATE=$(date -u +%Y%m%d)
MMDDHHII="$(date -u +%m%d)${RUN}00"

DIR_DATA=/home/raquel/Data/BUFR
DIR_PLOTS=/home/raquel/Plots/BUFR
fnameBUFR=${DIR_DATA}/BUFR-prec-${DATE}.txt

LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#################### EXTRACCIÓN BUFR DATOS ###########################
#FIXME quitar switch
switch_BUFR=1 #provisional para que no se descargue BUFR
if [[ ${switch_BUFR} -eq 1 ]]; then
#Edita archivo para filtro BUFR
{
  echo "set unpack=1;"
  echo "if (defined(totalPrecipitationOrTotalWaterEquivalent)) {"
  echo "print \"PREC,[/subsetNumber=XX/stationNumber],[/subsetNumber=XX/year],[/subsetNumber=XX/month%02d],[/subsetNumber=XX/day%02d],[/subsetNumber=XX/hour%02d],[/subsetNumber=XX/minute],[/subsetNumber=XX/totalPrecipitationOrTotalWaterEquivalent%.4f] [/subsetNumber=XX/totalPrecipitationOrTotalWaterEquivalent->units],[/subsetNumber=XX/longitude],[/subsetNumber=XX/latitude]\";"
  echo "}"
  #write;
} > filter_file_temp

#Sacamos los datos de los BUFR. Creamos un csv con datos y otro con la info de la estación
for ecenter in ${centro};do
  curl -s -m $LIM --connect-timeout $TIMEOUT "http://www.ogimet.com/getbufr.php?res=tar&beg="${fechaini}"&end=${fechafin}&ecenter="${ecenter}"&type=${tipo}" -o "${DIR_DATA}"/BUFR.tar
  mkdir "${DIR_DATA}"/BUFR_temp_"$ecenter"
  tar -xvf "${DIR_DATA}"/BUFR.tar -C "${DIR_DATA}"/BUFR_temp_"${ecenter}"

  for file_BUFR in $(ls "${DIR_DATA}"/BUFR_temp_"${ecenter}"/*_"${ecenter}"_*00.bufr );do
    #nsubset=$(bufr_get -p numberOfSubsets ${file_BUFR})
    nsubset=2

    for isubset in $(seq 1 "${nsubset}");do
      ##bufr_dump -Dfilter ${file_BUFR} > filter_file
      cat filter_file_temp | sed 's/XX/'${isubset}'/g' > filter_file
      bufr_filter filter_file ${file_BUFR} | grep "PREC" | grep -v "MISSING" | grep -v "undef" | awk -F',' '{if ($8>0) print $0}' >> filter.out.prec
    done

  done

  mv filter.out.prec $fnameBUFR

done #loop sobre ecenter

fi #condicional para desactivar descarga BUFR
exit
################ FIN EXTRACCIÓN BUFR ###############################################

#Sólo cojo las primeras 12 h
proy_HRES=$(seq --format %03g 0 3 24)

while read -r station station_number lon lat alt name
do

    fnamePREDIC=${DIR_DATA}/PREDIC-${station_number}-$fechaini-$fechafin
    fnameVALIDA=${DIR_DATA}/VALIDA-BUFR-${station_number}-$fechaini-$fechafin

  if [ ! -f $fnamePREDIC.json ]; then
      echo "Descarga json predicciones"
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='${station_number}'' -o $fnamePREDIC.json
  fi

  for PROY in ${proy_HRES} ; do

    #Grib con datos del ECMWF en bruto
    fnameGRIB=/home/ecmwf/${DATE}${RUN}/ECMWF_${DATE}${RUN}_${PROY}.grb

    if [[ -f ${fnameGRIB} ]]; then
      echo "$(datePID) extrayendo info de ${fnameGRIB} para $icao"
      #Sacamos el punto más cercano
      tp=($("${path_software}"/grib_get -l ${lat},${lon},1 -w shortName=tp -p date,step ${grib})) #no quitar paréntesis, es un vector
      tpECMWF=$(echo "${tp[2]}" )
      paso=$(echo "${tp[1]}" +  "${RUN}" | bc)
      fechaECMWF=$(echo  "${tp[0]}"*10000 +  "${paso}"*100 | bc)
      YYYY=$(echo $fechaECMWF | cut -c1-4)
      MM=$(echo $fechaECMWF | cut -c5-6)
      DD=$(echo $fechaECMWF | cut -c7-8)
      HH=$(echo $fechaECMWF | cut -c9-10)
      mm=$(echo $fechaECMWF | cut -c11-12)
      #Dato Meteored
      fechaPRED=$(echo $(date -d "${YYYY}/${MM}/${DD}H${HH}:${mm}" "+%s")*1000 | bc )
      tpPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .precipitacion.valor' $fnamePREDIC.json)
      #Dato Observación
      tpBUFR=$(cat "$fnameBUFR" | awk -F',' '{if ($2=="'${station_number}'" && $3=='$YYYY' && $4=='$MM' && $5=='$DD' && $6=='$HH') print $8}' | head -1)
      fechaBUFR=$(cat "$fnameBUFR" | awk -F',' '{if ($2=="'${station_number}'") print $3}' | head -1)

      if [ -z "$fechaBUFR" ]; then
        tpBUFR='NAN'
        fechaBUFR='NAN'
        tpBIAS='NAN'
        tpRMSE='NAN'
        tpBIAS_ECMWF='NAN'
        tpRMSE_ECMWF='NAN'
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
    npasos=$(cat ${fnameVALIDA}.txt | grep -v "NAN" | wc -l )
    echo "${station_number}" "$lon" "$lat" "$bias" "$rmse" "${rmseECMWF}" "${tempBUFR}" "${tempPRED}" | awk '{print $1,$2,$3,$4/'$npasos',sqrt($5/'$npasos'),sqrt($6/'$npasos'),$7/'$npasos', $8/'$npasos'}' | awk 'NF==8' >> ${DIR_DATA}/VALIDA-BUFR-mundo-$DATE.txt
    echo $npasos
#done < kkbufr

done < ${DIR_DATA}/BUFR-STATION-LEMM.csv

############## FIN VALIDACIÓN ###############################################

############### PINTAR MAPAS #######################################

filein=${DIR_DATA}/VALIDA-BUFR-mundo-${DATE}.txt
plotTemp=${DIR_PLOTS}/BUFR-temp-${DATE}.pdf
plotBias=${DIR_PLOTS}/BUFR-bias-${DATE}.pdf
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