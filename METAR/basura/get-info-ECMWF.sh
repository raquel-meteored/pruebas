#!/bin/bash
####################################################
# Script que extrae dato del ECMWF en la localidad del METAR
# Usa los gribs descomprimidos generados por ecmwf_bz2togrib
# Corre en usuario cep aunque use grib de ecmwf
#
# Raquel Lorente Plazas <raquel@meteored.com>
###################################################

# Nombre del script.
scriptName=$(basename $0)

# Formato de fecha para el fichero .log.
function datePID() {
  echo "$(date -u +%Y-%m-%d\ %H:%M:%S) UTC [$$]"
}

# Comprobación de que existe software para optimizar.
#TODO solo dejo el nombre del software sin el path (diferencia entre command y which?)
software="grib_get"
which ${software} > /dev/null 2>&1 || { echo "$(datePID): ${software} no está instalado." && exit 1; }
path_software=$(which ${software})

# Función que muestra la ayuda.
function showUsage() {
  echo
  echo "Uso: ${scriptName} 00|12 [-d|--date AAAAMMDD] [-p|--prefix A1|T1] [-h|--help]"
  echo
  echo "                       00|12 - Hora de inicio de la pasada."
  echo "        [-d|--date AAAAMMDD] - Fecha de inicio de la pasada."
  echo "         [-p|--prefix A1|T1] - Si se especifica, se buscarán gribs que comiencen por A1 o T1. Por defecto A1."
  echo "                 [-h|--help] - Se muestra esta ayuda."
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
DIR_BASE=/home/cep/METAR
DIR_DATA=$DIR_BASE/data/VALIDACION
mkdir -p ${DIR_DATA}


# Valores por defecto.
cc="A1"
S="D" # modelo determinista
DATE=$(date -u +%Y%m%d)
MMDDHHII="$(date -u +%m%d)${RUN}00"
weekDOWNLOAD=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse


# Definición de fichero de bloqueo y comprobación de estado.
lockFile="/home/cep/${scriptName}_${DATE}${RUN}.lock"
if [[ -e ${lockFile} ]] ; then
  if [[ $(stat -c %Y ${lockFile}) -lt $(date -u +%s --date="30 minutes ago") ]] ; then
    touch ${lockFile} # Problemas: el fichero ${lock} es muy antiguo.
  else
    exit # Ya está ocupado.
  fi
else
  touch ${lockFile}
fi

###Descarga METARs info: lon lat alt (LE españoles)
filemetarID=meteoflight_reports.php #se descarga
echo "$(datePID): Inicia descarga de $filemetarID"
curl -s -m $LIM --connect-timeout $TIMEOUT http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
echo "$(datePID): Fin descarga de $filemetarID"
metarID=$(cat "$filemetarID" | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)

#Sólo cojo las primeras 24 h
proy_HRES=$(seq --format %03g 0 3 23)
proy=(${proy_HRES[@]})

for ((i=0; i<${#proy[@]}; i++)) ; do
  # Caso de fichero de análisis.
  if [[ $(( 10#${proy[$i]} )) -eq 0 ]] ; then
    mmddhhii="$(date -u +%m%d%H%M --date="${DATE} ${RUN} 1 minute")"
  # Resto de casos.
  else
    mmddhhii="$(date -u +%m%d%H%M --date="${DATE} ${RUN} $(( 10#${proy[$i]} )) hours")"
  fi

  # Definimos los ficheros con los que vamos a trabajar y
  # comprobamos el estado de la proyección.
  grib=/home/ecmwf/${cc}${S}${MMDDHHII}${mmddhhii}1
    if [[ -f ${grib} ]]; then
      for icao in $metarID; do
        touch ${lockFile} &&
        fnameECMWF=$DIR_DATA/ECMWF-$icao-$weekDOWNLOAD.txt
        echo "$(datePID) extrayendo info de ${grib} para $icao"

        lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
        lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')

        temp2t=($(${path_software} -l ${lat},${lon},1 -w shortName=2t -p date,step ${grib}))
        echo $temp2t ${path_software}

        fechaECMWF=$(echo  "${temp2t[0]}"*10000 +  "${temp2t[1]}"*100 | bc)
        tempC=$(echo ${temp2t[2]} - 273.15 | bc )
        #Nos aseguramos que los datos se comparan con la última pasada
        #sobreescibiendo en las fechas ya exisistentes
        echo $fechaECMWF $fnameECMWF
        if [ -e $fnameECMWF ]
        then
          mv  $fnameECMWF kkrmdate
          cat kkrmdate | grep -v $fechaECMWF  >  $fnameECMWF
          rm kkrmdate

        fi
        echo $fechaECMWF $tempC >> $fnameECMWF
      done # end icao loop
    else
      echo "$(datePID) no exite ${grib} ..."
      rm ${lockFile}
      exit
    fi
done #end grib files loop
rm ${lockFile}