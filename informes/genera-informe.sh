#!/bin/bash
####################################################################################
### Descarga METARs info y las predicciones del ECMWF en la localidad de los METARs
### Compara temperaturas
### Pinta series con R
### RLP 11-2019
###################################################################################
# Nombre del script.
scriptName=$(basename $0)
PATHsoft1=/usr/bin
PATHsoft2=/usr/local/bin
# Formato de fecha para el fichero .log.
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

#TODO validar parámetros de entrada
#zona='Europe/Madrid'

function showUsage {
  echo
  echo " Uso: ${scriptName}  "
  echo
  echo "      []     - Longitude."
  echo "      xxx    - Latitude."
  echo "      xxx    - altitud"
  echo "      xxx    - Zona horaria"
  echo "      xxx    - Nombre Localidad"
  echo
}

# Comprobación de argumentos de entrada.
if [ ${#} -lt 2 ] ; then
  showUsage
  exit 1
else
  if [[ "${1}" =~ ^[a-zA-Z]+$ && "${2}" =~ [a-zA-Z/a-zA-Z] ]] ; then
    name="${1}"
    zona="${2}"
  else
    echo 'Check location: name and zona horaria'
    showUsage
    exit 1
  fi
  if [[ "${3}" =~ ^-?[0-9]*[.]?[0-9]*$ && "${4}" =~ ^-?[0-9]*[.]?[0-9]*$ && "${5}" =~ ^-?[0-9]*[.]?[0-9]*$ ]] ; then
    lon="${3}"
    lat="${4}"
    alt="${5}"
  else
    echo 'Check coordenates: longitude, latitude and altitude'
    showUsage
    exit 1
  fi
fi

# Comprobación de que existe software para optimizar.
#FIXME solo dejo el nombre del software sin el path (diferencia entre command y which?)
Rscript="/usr/bin/Rscript"
command -v ${Rscript} > /dev/null 2>&1 || { echo "$(datePID): ${Rscript} no está instalado." && exit 1; }

# Comprobación de que existe ficheros

fileLOGO=${DIR_BASE}//home/raquel/repos/pruebas/informes/meteoredlogo.pdf

if [[ ! -e $fileLOGO ]]; then
	echo "$(datePID): $fileLOGO no exite"
  exit 1;
fi


LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

fnamePREDIC=file-$name
#curl -s -m $LIM --connect-timeout $TIMEOUT 'http://halcon.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria='$zona'&name='$name'' -o "$fnamePREDIC".json
curl -s -m $LIM --connect-timeout $TIMEOUT 'http://halcon.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria='$zona'&name='$name'' -o "$fnamePREDIC".json
cp $fnamePREDIC.json /home/raquel/data/prueba.json
Rscript starter.R
