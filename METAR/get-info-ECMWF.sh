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

#Sólo cojo las primeras 24 h
proy_HRES=$(seq --format %03g 0 3 12)
proy=(${proy_HRES[@]})

for ((i=0; i<${#proy[@]}; i++)) ; do

  mmddhhii="$(date -u +%m%d%H%M --date="${DATE} ${RUN} $(( 10#${proy[$i]} )) hours")"
  # Definimos los ficheros con los que vamos a trabajar y
    # comprobamos el estado de la proyección.
    grib=/home/ecmwf/${cc}${S}${MMDDHHII}${mmddhhii}1

    if [[ -f ${grib} ]]; then

      echo "$(datePID) extrayendo info de ${grib} ..."
      touch ${lockFile} &&
      lat=0
      lon=0
      icao="pru"
      #FIXME sobreescribir las fechas ya existentes
      temp2t=$(grib_get -l ${lat},${lon},1 -w shortName=2t -p date,step ${grib})
      echo $temp2t
      echo $temp2t[2]
      else
      echo "$(datePID) no exite ${grib} ..."
      rm ${lockFile}
      exit
    fi
done
rm ${lockFile}