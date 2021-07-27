#!/bin/bash
####################################################################################
### Extrae información sobre las estaciones de los BUFR
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

# Función que muestra la ayuda.
function showUsage() {
  echo
  echo "Uso: ${scriptName}  [-h|--help]"
  echo "        [-h|--help] - Se muestra esta ayuda."
  echo
}



echo "$(datePID): Inicia descarga de BUFR"
#centro="LEMM LFPW ETGT"
centro="LEMM"
tipo=IS

# Valores por defecto.
fechafin="$(date -u +%Y%m%d%H)"00
fechaini="$(date -u +%Y%m%d%H -d "-12 hours")"00

DIR_DATA=/home/raquel/Data/BUFR

LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#################### EXTRACCIÓN BUFR DATOS ###########################

#Edita archivo para filtro BUFR
{
  echo "set unpack=1;"
#  echo "if (defined(airTemperature)) {"
  echo "print \"STATION,[/subsetNumber=XX/stationNumber],[/subsetNumber=XX/longitude],[/subsetNumber=XX/latitude],[/subsetNumber=XX/heightOfStationGroundAboveMeanSeaLevel],[/subsetNumber=XX/stationOrSiteName] \";"
#  echo "}"
  #write;
} > filter_file_temp

#Sacamos los datos de los BUFR. Creamos un csv con datos y otro con la info de la estación

for ecenter in ${centro};do
  if [ -e ${DIR_DATA}/BUFR-STATION-$ecenter.csv ]; then
     cp ${DIR_DATA}/BUFR-STATION-$ecenter.csv station-list.csv
  else
     tauch station-list.csv
  fi
 # curl -s -m $LIM --connect-timeout $TIMEOUT "http://www.ogimet.com/getbufr.php?res=tar&beg="${fechaini}"&end=${fechafin}&ecenter="${ecenter}"&type=${tipo}" -o "${DIR_DATA}"/BUFR.tar
 # mkdir "${DIR_DATA}"/BUFR_temp_"$ecenter"
 # tar -xvf "${DIR_DATA}"/BUFR.tar -C "${DIR_DATA}"/BUFR_temp_"${ecenter}"

  for file_BUFR in $(ls "${DIR_DATA}"/BUFR_temp_"${ecenter}"/*_"${ecenter}"_*00.bufr );do
    nsubset=$(bufr_get -p numberOfSubsets ${file_BUFR})
    #nsubset=2

    for isubset in $(seq 1 "${nsubset}");do

      cat filter_file_temp | sed 's/XX/'${isubset}'/g' > filter_file
      bufr_filter filter_file ${file_BUFR} | grep -v "MISSING" | grep -v "undef" >  filter.out.station
      station_number=$(awk -F',' '{print $2}' filter.out.station)
      station_list=$(awk -F',' '{print $2}' station-list.csv)
      rep_station=$(echo "${station_list}" | grep -w "${station_number}")

      if [ -z "${rep_station}" ]; then
        cat filter.out.station >> station-list.csv
      fi

    done

  done

  cat station-list.csv | grep -v "Coincidencia" | grep -v "ERROR" | sed s/STATION/${ecenter}/g | sort -n > "${DIR_DATA}"/BUFR-STATION-"${ecenter}".csv

done #loop sobre ecenter



