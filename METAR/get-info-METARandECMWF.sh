#!/bin/bash
####################################################################################
### Descarga METARs info y las predicciones del ECMWF en la localidad de los METARs 
### Compara temperaturas
### Pinta series con R
### RLP 11-2019
###################################################################################
# Nombre del script.
scriptName=$(basename $0)

# Formato de fecha para el fichero .log.
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

# Comprobación de que existe software para optimizar.
Rscript="/usr/bin/Rscript"
command -v ${Rscript} > /dev/null 2>&1 || { echo "$(datePID): ${Rscript} no está instalado." && exit 1; }

#Fechas y limites temporales
dateDOWNLOAD=$(date +%Y%m%d%H%M)
weekDOWNLOAD=$(date '+%W')
LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#Directorios
DIR_BASE=/home/cep/METAR
DIR_DATA=$DIR_BASE/data/VALIDACION
DIR_PLOTS=$DIR_DATA/PLOTS

#Ficheros
filegeonameID=${DIR_BASE}/geonameId-icao-correspondencia.txt #uso este fichero para que gonameID siempre correspoda al mismo METAR
filemetarID=meteoflight_reports.php

# Comprobación de que existen los directorios y ficheros
mkdir -p ${DIR_DATA} ${DIR_PLOTS}
if [[ ! -e $filegeonameID ]]; then
	echo "$(datePID): $filegeonameID no exite"
  exit 1;
fi

# Definición de fichero de bloqueo y de finalización.
# Se comprueba si se está trabajando ya.
#scriptName=$(basename $0 .sh)
#lockFile=${DIR_DATA}/${scriptName}_${dateDOWNLOAD}.lock
#if [[ -e ${lockFile} ]] ; then
#  if [[ $(stat -c %Y ${lockFile}) -gt $(date -u +%s --date="180 minutes ago") ]] ; then
#    exit # Problemas: el fichero ${lock} es muy antiguo.
#  else
#    touch ${lockFile}
#  fi
#fi

###Descarga METARs info (LE españoles)
if [[ -e ${filemetarID} ]] ; then
  rm -f $filemetarID
fi

echo "$(datePID): Inicia descarga de $filemetarID"
curl -s http://aire.ogimet.com/meteoflight_reports.php -o $filemetarID
echo "$(datePID): Fin descarga de $filemetarID"
metarID=$(cat $filemetarID | jq '.points[].icao' | grep 'LE[A-Z][A-Z]' | cut -c2-5)

#Truco de Juan para asegurarme que tengo todos los json descargados adecaudamente
ficherosdescargados=0
while [ ${ficherosdescargados} -eq 0 ]
do
  #loop sobre los METARs para descargar la predicción
  #i=0
  for icao in $metarID; do   	  
    fnameMETAR=${DIR_DATA}/METAR-$icao-${dateDOWNLOAD}
    fnamePREDIC=${DIR_DATA}/PREDIC-$icao-${dateDOWNLOAD}
    fnameVALIDA=${DIR_DATA}/VALIDA-$icao-${weekDOWNLOAD}
  
    #i=$(echo $i + 1 | bc)
    #imet=$(echo $i + 1 | bc)
    #geonameId=$(echo 899999999 - $imet | bc)

    ##Descarga METARs info (24h data) from json file
    curl -s http://aire.ogimet.com/meteoflight_reports.php?ICAO=$icao -o $fnameMETAR.json    
    cat $fnameMETAR.json | jq '.metar_speci[].hour' > kkfecha
    cat $fnameMETAR.json | jq '.metar_speci[].report' | grep -o '[ M][0-9][0-9]/[M]*[0-9][0-9]' | tr "M" "-" | cut -c1-3  > kktemp
    paste kkfecha kktemp > $fnameMETAR.txt

    geonameId=$(cat $filegeonameID | grep "$icao" | awk '{print $2}')
    lat=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lat] | sort []')
    lon=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .lon] | sort []')
    alt=$(cat $filemetarID | jq '[.points[] | select(.icao == "'$icao'") | .alt] | sort []')

    if [ ! -e $fnamePREDIC.json ]
    then
      ##Descarga forecast info del json file
      curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?geonameId='$geonameId'&latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$icao'' -o $fnamePREDIC.json
      if [ $? -eq 0 ]
      then
        cat $fnamePREDIC.json | jq '.dias[].horas[].utime' >pp1
        cat $fnamePREDIC.json | jq '.dias[].horas[].temperatura.valor' >pp2
        paste pp1 pp2 > $fnamePREDIC.txt
	rm pp*

	## Uso la fecha inicial del fichero para hacerme una idea del LEAD time
        fechaSTART=$(cat $fnamePREDIC.json | jq '.dias[0].utime.start')
        fechaSTARTok=$(date --date=@$(echo $fechaSTART/1000 | bc) '+%Y%m%d%H%M')

        ##Compara forecast y METAR
	##Recorre los pasos temporales donde hay dato de temp
        nts=$(cat kktemp | wc -l )
        for its in $(seq 1 $nts);do
           temp=$(cat $fnameMETAR.txt | awk '{print $2}' | head -$its | tail -1)
           fechaMETAR=$(cat $fnameMETAR.txt | awk '{print $1}' | head -$its | tail -1)
           fechaMETARok=$(date --date=@$(echo $fechaMETAR/1000 | bc) '+%Y%m%d%H%M')

           echo $(expr \( $fechaMETAR - $fechaSTART \) \/ 3600000) >kkfechaLEAD #horas entre inicio de predic y METAR
           fechaLEAD=$(cat kkfechaLEAD | awk '{print $0}')

           #Nos aseguramos que no tenemos datos de varias pasadas
            if [ -e $fnameVALIDA.txt ]
            then
              mv  $fnameVALIDA.txt kk
              grep -v "'$fechaMETAR'" kk >  $fnameVALIDA.txt
            fi

	    # Busca la fecha de la predicción más cercana a la del METAR (sort) 
	    # fecha PREDIC y METAR (minu), fecha PREDIC, PREDIC, fecha METAR, METAR, PREDIC-METAR, fecha METAR, fecha ini-json, fecha ini-json y METAR (horas)
           cat  $fnamePREDIC.txt | awk '{print  sqrt(($1 - '$fechaMETAR')**2)/60000, $0,'$fechaMETAR','$temp',$2-'$temp','$fechaMETARok','$fechaSTARTok','$fechaLEAD',"'$icao'"}' | sort -n | head -1  >> $fnameVALIDA.txt
        done
        cat $fnameVALIDA.txt | awk '{if (sqrt($6*$6) > 2 ) print "'$icao'",$0,'$fechaLEAD'}' >> ${DIR_DATA}/DIFGT2-predic-metar-$weekDOWNLOAD.txt
        cat $fnameVALIDA.txt | awk '{print sqrt($6*$6), "'$icao'", "'$lon'", "'$lat'", $0,'$fechaLEAD'}' | sort -rn | head -1 >> ${DIR_DATA}/DIFMAX-predic-metar-$weekDOWNLOAD.txt
        
	echo "$(datePID): Ini plots w R $icao"
	Rscript --vanilla ${DIR_BASE}/plot-PREDICvsMETAR.R $fnameVALIDA.txt ${DIR_PLOTS}/T-PREDIC-METAR-$icao-$weekDOWNLOAD.pdf $icao $fechaSTART ${DIR_DATA}/MEAN-BIAS-$icao-$weekDOWNLOAD.txt
	echo "$(datePID): Fin plots w R $icao"
        mv $fnameMETAR.txt $fnamePREDIC.txt  ${DIR_DATA}/basura
      elif [ -e ${DIR_DATA}/PREDIC-$icao.json ]
      then
        rm $fnamePREDIC.json
      fi
    fi
  done

  ficherosdescargados=1
  for icao in $metarID; do
    if [ ! -e $fnamePREDIC.json ]
    then
      ficherosdescargados=0;
      break;
    fi
  done
done
#mv *.json ${DIR_DATA}/basura
#rm -f ${lockFile}
echo 'fin script predicciones'
