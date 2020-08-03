#!/bin/bash
####################################################################################
### Extrae información sobre las estaciones de los SYNOP
### Compara:
#       - con las predicciones del ECWMF y de METEORED
#       - para precipitación, t2m y v10m
###
### Creado en 06-2020
# Raquel Lorente Plazas <raquel@meteored.com>
# Marcos Molina Cano <marcos@meteored.com>
# Juan Sanchez Segura <jsanchez@meteored.com>
# Guillermo Ballester Valor <gbv@ogimet.com>
###################################################################################
# Nombre del script.
scriptName=$(basename "$0")

# Formato de fecha
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

# Función que define la ayuda sobre este script.
function showUsage {
  echo
  echo "Uso: ${scriptName} HH [-d|--date AAAAMMDD] [-D|--Day -1|-2] [-h|--help]"
  echo
  echo "Opciones:"
  echo "  HH"
  echo "      00 para la pasada de las 00 UTC y 12 para la pasada de las 12 UTC."
  echo "  [-d|--date AAAAMMDD|[-1|-2]]"
  echo "      Puede ser AAAAMMDD que es la fecha de la pasada o -1 o -2 que es el número"
  echo "      a restar al día actual. Por ejemplo, -1 sería la pasada de ayer y -2 sería antes de ayer."
  echo "  [-h|--help]"
  echo "      Se muestra esta ayuda."
  echo ""
}

# Control de los argumentos imprescindibles.
if [[ $# -eq 0 ]] ; then
  showUse
  exit 1

elif [[ $# -gt 0 ]] ; then

  if [[ "$1" == "00" ]] || [[ "$1" == "12" ]] ; then
    pasada="$1"
  else
    showUse
    exit 1
  fi

fi

# Valores opcionales.
fecha=$(date -u +%Y%m%d)
regfecha="^[0-9]{8}$"

# Control del resto de argumentos opcionales.
TEMP=$(getopt -n ${scriptName} -o d:D:h --long date:,Day:,help -- "$@")
[[ $? -eq 0 ]] || { echo "Error: getopt ha devuelto un código distinto de 0." ; showUse; exit 1 ; }
eval set -- "${TEMP}"

while true ; do

  case "$1" in

    -d|--date)
      shift
      if [[ $1 =~ ${regfecha} ]] ; then
        fecha=$1
      else
        echo "Error: $1 no tiene formato de fecha válido." >&2
        exit 1
      fi
      ;;

    -D|--Day)
      shift
      [[ $1 =~ ${regneg} ]] && [[ $1 -le 0 ]] && [[ $1 -ge -2 ]] && day_des=$1 || { echo "Error: $1 debe un número de días para restar o sumar al actual." >&2; exit 1; }
      fecha=$(date -u +%Y%m%d --date="${day_des} days")
      ;;

    -h|--help)
      showUse
      exit ;;

    --)
       shift
       break ;;

    *)
      echo "Internal error!"
      exit 1;;

  esac
  shift
done

# Valores por defecto.
YYYYMMDDHH=${fecha}${pasada}
YYYY=$(echo "${fecha}" | cut -c1-4)
MM=$(echo "${fecha}" | cut -c5-6)
DD=$(echo "${fecha}" | cut -c7-8)

#Hay que coger un día completo para desacumular la precip de los SYNOP
fechaini=${fecha}0000
fechafin=$(date -d"00:00 ${fecha} +25 hours" +"%Y%m%d%H%M")

LIM=350 #maxímo número de segundos de descarga
TIMEOUT=60 #máximo número de segundos intentando conectarse

#Comprobación de que existen los directorios
DIR_BASE=/home/raquel/repos/pruebas/VALIDA
DIR_DATA=/home/raquel/Data/SYNOP
DIR_PLOTS=/home/raquel/Plots/SYNOP
PREFIX=${DIR_BASE}

mkdir -p ${DIR_DATA} ${DIR_PLOTS}

# Definición de ficheros necesarios.
finishedFile="${PREFIX}"/finished_"${scriptName}"_"${fecha}"_"${pasada}"
lockFile="${PREFIX}"/${scriptName}.lock

#Comprobación de que existen los Ficheros
#filesynopID=${DIR_BASE}/station-list.csv #coordenadas de los synop
filesynopID=${DIR_BASE}/station-list.json
#if [[ -e ${filemetarID} ]] ; then
#  rm -f $filemetarID
#fi

# Se comprueba si la tarea ya se ha realizado.
test -e "${finishedFile}" && exit

# Si existe el fichero de bloqueo y tiene menos de X minutos termina.
if [[ -e "${lockFile}" ]]; then

  if [[ $(stat -c %Y "${lockFile}") -lt $(date -u +%s --date="20 minutes ago") ]]; then
    echo "$(datePID): Archivo de bloqueo demasiado antiguo. Borrando y creando..."
    touch "${lockFile}"
  else
    echo "$(datePID): Archivo de bloqueo existente. Saliendo..."
    exit
  fi

else
  echo "$(datePID) - Inicio"
  touch "${lockFile}"
fi

# Comprobación de que existe software para optimizar.
Rscript="/usr/bin/Rscript"
Jsonjq="/usr/bin/jq"
GRIB_GET="/usr/bin/grib_get"

command -v ${Rscript} > /dev/null 2>&1 || { echo "$(datePID): ${Rscript} no está instalado." && exit 1; }
command -v ${GRIB_GET} > /dev/null 2>&1 || { echo "$(datePID): ${GRIB_GET} no está instalado." && exit 1; }
command -v ${Jsonjq} > /dev/null 2>&1 || { echo "$(datePID): ${Jsonjq} no está instalado." && exit 1; }

echo "$(datePID): Inicia descarga de SYNOP"
#TODO Marcos
##Descarga SYNOP coord: lon lat alt
curl -s -m $LIM --connect-timeout $TIMEOUT "http://aire.ogimet.com/cgi-bin/getsynop?begin=${fechaini}00&state=Spa&format=json" -o $filesynopID
exit
##Descarga SYNOP info
fnameSYNOP=${DIR_BASE}/synop-${fechaini}-${fechafin}.csv #datos
if [[ ! -e ${fnameSYNOP} ]] ; then
  curl -s -m $LIM --connect-timeout $TIMEOUT "https://www.ogimet.com/cgi-bin/getsynop?begin=${fechaini}00&end=${fechafin}00&state=Spa" -o $fnameSYNOP
fi
echo "$(datePID): Fin descarga de SYNOP"

synopID=$(cat "$filesynopID" |  awk -F "," '{print $1}')

#Resolución temporal de la precipitación
#prec_tr es el código y prec_res la resolución correspondiente en horas
#horas1h="01 02 04 05 07 08 10 11 13 14 16 17 19 20 22 23"
#horas3h="03 09 15 21"
#horas6h="00 12"
#horas12h="06 18"
horas=($(seq -w 0 23))
prec_res=(6 1 1 3 1 1 12 1 1 3 1 1 6 1 1 3 1 1 12 1 1 3 1 1)
prec_tr=(1 5 5 7 5 5 2 5 5 7 5 5 1 5 5 7 5 5 2 5 5 7 5 5)

for station in ${synopID}; do

  fnamePREDIC=${DIR_DATA}/PREDIC-"${station}".json
  fnameVALIDAt2=${DIR_DATA}/validat2-"${station}".txt
  fnameVALIDAv10=${DIR_DATA}/validav10-"${station}".txt
  fnameVALIDAtp1h=${DIR_DATA}/validaPREC-"${station}".txt

  #Coordenadas
  lat=$( cat ${filesynopID} | awk -F "," '{if ($1=="'$station'") print $2}')
  lon=$( cat ${filesynopID} | awk -F "," '{if ($1=="'$station'") print $3}')
  alt=$( cat ${filesynopID} | awk -F "," '{if ($1=="'$station'") print $4}')

  #Descarga forecast info del json file en la localidad del SYNOP
  echo "$(datePID): Inicio descarga de json"
  curl -s -m $LIM --connect-timeout $TIMEOUT 'http://aguila.ogimet.com/cgi-bin/otf12?latitud='$lat'&longitud='$lon'&altitud='$alt'&zonaHoraria=etc/UTC&name='$station'' -o "${fnamePREDIC}"
  echo "$(datePID): Fin descarga de json"

  for i in $(seq 0 23);do
    #FECHAS
    hora=${horas[$i]}
    fechaSYNOP=$(cat "${fnameSYNOP}" | awk -F "," '{if ($1=="'$station'" && $4=="'$DD'" && $5=="'$hora'") print $2$3$4$5$6}')

    #Primero comprobamos que exiten lo gribs
    PROY=$(printf '%03g' $hora)
    PROY_INI=$(echo ${PROY} - 1 | bc)

    fnameGRIB=/home/ecmwf/${YYYYMMDDHH}/ECMWF_${YYYYMMDDHH}_${PROY}.grb

    if [[ ! -f ${fnameGRIB} ]]; then
      echo $fnameGRIB does not exist
      rm $lockFile
      exit
    fi

    #Nos quedamos con las secciones del SYNOP
    cat "$fnameSYNOP" | awk -F "," '{if ($1=="'$station'" && $4=="'$DD'" && $5=='${hora}') print $7}' > kkestaciones

    #Dentro de las secciones del SYNOP buscamos, T2m, V10m y Precip:

    ##PRECIPITACIÓN
    #grupo 6 es precipitación 6PPPtr; donde tr es la resolucion temporal
    sec1gr6=$(cat kkestaciones | cut -d' ' -f4- | grep -o '[6][0-9][0-9][0-9]['${prec_tr[$i]}']')
    trace=${sec1gr6[0]:1:2}
    lenPrecip=${#sec1gr6[@]}
    ir=$(cat kkestaciones | cut -d' ' -f4 | cut -c1) #indicador de inclusión de precip (sec 1 grupo irixhVV)

    #Si PP=99 entonces la otra P son décimas de precipitación
    if [[ $trace -eq '99' ]]; then
      precSYNOP=$(echo "scale=4;${sec1gr6:3:1}*0.1" | bc)
    else
      precSYNOP=${sec1gr6:1:3}
    fi

    #Construimos un vector para poder desacumular: 1h, 3h y 24h
    PRECIP["$i"]=$precSYNOP

    if [[ "${hora}" == 03 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[3]} - ${PRECIP[2]} - ${PRECIP[1]} | bc )
      precip3h=${PRECIP[3]}
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    elif [[ "${hora}" == 06 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[0]} - ${PRECIP[3]} - ${PRECIP[4]} - ${PRECIP[5]} | bc )
      precip3h=$(echo ${PRECIP[0]} - ${PRECIP[3]} | bc )
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    elif [[ "${hora}" == 09 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[9]} - ${PRECIP[7]} - ${PRECIP[8]} | bc )
      precip3h=${PRECIP[9]}
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    elif [[ "${hora}" == 12 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[12]} - ${PRECIP[9]} - ${PRECIP[10]} - ${PRECIP[11]} | bc )
      precip3h=$(echo ${PRECIP[12]} - ${PRECIP[9]} | bc)
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    elif [[ "${hora}" == 15 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[15]} - ${PRECIP[13]} - ${PRECIP[14]} | bc )
      precip3h=${PRECIP[15]}
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    elif [[ "${hora}" == 18 ]]; then

      tp1hSYNOP=$(echo ${PRECIP[18]} - ${PRECIP[12]} - ${PRECIP[15]} - ${PRECIP[16]} - ${PRECIP[17]}| bc )
      precip3h=$(echo ${PRECIP[18]} - ${PRECIP[12]} - ${PRECIP[15]} | bc )
      echo ${DD} ${hora} $precip3h $sec1gr6  >> ts-precip3h-$station

    else

      tp1hSYNOP=${PRECIP["$i"]}

    fi

    echo ${DD} ${hora} $tp1hSYNOP $sec1gr6 ${prec_res[$i]} $ir ${prec_tr[$i]} $i  >> ts-precip1h-$station

    #Cálculos trihorarios
    multiple=$(( ${i} % 3 ))

    if [[ $multiple -ne 0 || ${hora} -eq 0 ]]; then
        echo $hora no es multiplo de 3
        continue
    fi

    ##TEMPERATURA
    #grupo 1 es temperatura 1SnTTT; donde Sn es el signo
    sec1gr1=($(cat kkestaciones | awk '{print $6}' | grep -o '[1][0-1][0-9][0-9][0-9]'))
    SN=${sec1gr1:1:1} #Nos da el signo
    temp=${sec1gr1[0]:2:3} #Valor temp

    if [[ -z $temp ]]; then
      tempSYNOP=NAN
    else
      if [[ $SN -eq 1 ]]; then
        tempSYNOP=$(echo "scale=4;${temp}*-0.1" | bc)
      else
        tempSYNOP=$(echo "scale=4;${temp}*0.1" | bc)
      fi
    fi

    #VIENTO
    #grupo Nddff es viento dd dirección y ff velocidad
    #Para saber la unidades; sección0 grupo YYGGiw (iw nudos o m/s)
    sec0gr1=$(cat kkestaciones | awk '{print $2}')
    iw=${sec0gr1:4:1} #Nos da las unidades
    sec1grN=$(cat kkestaciones | awk '{print $5}')
    vv=${sec1grN:3:2}

    #Unidades en m/s
    if [[ -z $vv ]]; then
      windSYNOP=NAN
    else
      if [[ $iw -gt 3 ]]; then
        windSYNOP=$(echo "scale=4;${vv}*0.514" | bc)
      else
        windSYNOP=${sec1grN:3:2}
      fi
    fi

    #VALIDACIÓN
    ##ECMWF: Grib con datos del ECMWF en bruto
    temp2t=($(${GRIB_GET} -l ${lat},${lon},1 -w shortName=2t -p date,step ${fnameGRIB}))
    tp1h=($(${GRIB_GET} -l ${lat},${lon},1 -w shortName=tp,stepRange=${PROY_INI}-${i} -p date,step ${fnameGRIB}))
    v10=($(${GRIB_GET} -l ${lat},${lon},1 -w shortName=10v -p date,step ${fnameGRIB}))
    u10=($(${GRIB_GET} -l ${lat},${lon},1 -w shortName=10u -p date,step ${fnameGRIB}))

    tempECMWF=$(echo ${temp2t[2]} - 273.15 | bc )
    tp1hCMWF=${tp1h[2]}
    windECMWF=$(echo ${v10[2]} ${u10[2]} | awk '{print sqrt ($1*$1 + $2*$2)}')
    paso=$(echo "${temp2t[1]}" + "${pasada}" | bc)
    # fechaECMWF=$(echo  "${temp2t[0]}"*10000 +  "$paso"*100 | bc)
    fechaECMWF=$(date -d"00 ${temp2t[0]} +$paso hours" +"%Y%m%d%H" | bc)

    ##METEORED: Comparamos con la predicción de meteored dentro de un json
    #Buscamos la hora unix correspondiente a la UTC del SYNOP
    fechaPRED=$( echo $(date -u -d "${fechaECMWF:0:4}-${fechaECMWF:4:2}-${fechaECMWF:6:2} ${fechaECMWF:8:2}:00:00" "+%s")*1000 | bc )

    tempPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .temperatura.valor' $fnamePREDIC)
    precPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .precipitacion.valor' $fnamePREDIC)
    vvPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .viento.velocidad' $fnamePREDIC)
    windPRED=$(echo "scale=4;${vvPRED}*0.28" | bc)
    horaPRED=$(jq '.dias[].horas[] | select (.utime == '$fechaPRED') | .hora' $fnamePREDIC)

    #Estadísticos
    tempBIAS_PRED=$(echo $tempPRED - $tempSYNOP | bc)
    precBIAS_PRED=$(echo $precPRED - $tp1hSYNOP | bc)
    windBIAS_PRED=$(echo $windPRED - $windSYNOP | bc)

    tempBIAS_ECMWF=$(echo $tempECMWF - $tempSYNOP | bc)
    precBIAS_ECMWF=$(echo $tp1hECMWF - $tp1hSYNOP | bc)
    windBIAS_ECMWF=$(echo $windECMWF - $windSYNOP | bc)

    if [[ -z $tempSYNOP ]]; then
      tempSYNOP=NAN
      tempBIAS_PRED=NAN
      tempBIAS_ECMWF=NAN
    fi

    if [[ -z $tp1hSYNOP ]]; then
      tp1hSYNOP=NAN
      precBIAS_ECMWF=NAN
      precBIAS_PRED=NAN
    fi

    if [[ -z $windSYNOP ]]; then
      windSYNOP=NAN
      windBIAS_ECMWF=NAN
      windBIAS_PRED=NAN
    fi

    #echo $station $lon $lat $fechaSYNOP $tempSYNOP $tp1hSYNOP $tempPRED $precPRED $tempBIAS $precBIAS $sec1gr6  $sec1gr1  $seccion3 $lenPrecip | grep -v "NAN" >> prueba-$fechaSYNOP
    echo $station $lon $lat synop=$fechaSYNOP e=$fechaECMWF $tempSYNOP $tempPRED $tempECMWF ${tempBIAS_PRED} ${tempBIAS_ECMWF} ${horaPRED} | grep -v "NAN" >> t2
    echo $station $lon $lat synop=$fechaSYNOP e=$fechaECMWF $tp1hSYNOP $precPRED $tp1hECMWF ${precBIAS_PRED} ${precBIAS_ECMWF} ${horaPRED} | grep -v "NAN" >> tp1h
    echo $station $lon $lat synop=$fechaSYNOP e=$fechaECMWF $windSYNOP $windPRED $windECMWF ${windBIAS_PRED} ${windBIAS_ECMWF} ${horaPRED} | grep -v "NAN" >> v10
    rm kkestaciones
  done #loop hora

  #Renombrar archivos para que se machaquen
  mv t2 ${fnameVALIDAt2}
  mv v10 ${fnameVALIDAv10}
  mv tp1h ${fnameVALIDAtp1h}
  mv ts-precip3h-"$station" ${DIR_DATA}/PRECIP3h-"$station"-"${fechaini}".txt
  mv ts-precip1h-"$station" ${DIR_DATA}/PRECIP1h-"$station"-"${fechaini}".txt

  #Media de precip diaria
  precip24h=$(echo ${PRECIP[6]} - ${PRECIP[0]} + ${PRECIP[18]} + ${PRECIP[21]} + ${PRECIP[22]} + ${PRECIP[23]} | bc )
  echo ${DD} $precip24h $station >> ts-PRECIP24h.txt
  mv ts-PRECIP24h.txt ${DIR_DATA}/PRECIP24h-"${fechaini}".txt

  #Promedios temporales
  temp_MEAN_SYNOP=$(cat "${fnameVALIDAt2}" | grep -v "NAN" | awk '{s+=$6}END{print s}' )
  temp_MEAN_PRED=$(cat "${fnameVALIDAt2}" | grep -v "NAN" | awk '{s+=$7}END{print s}' )
  temp_MEAN_ECMWF=$(cat "${fnameVALIDAt2}" | grep -v "NAN" | awk '{s+=$8}END{print s}' )
  temp_meanBIAS_PRED=$(cat "${fnameVALIDAt2}"| grep -v "NAN" | awk '{s+=$9}END{print s}' )
  temp_meanBIAS_ECMWF=$(cat "${fnameVALIDAt2}" | grep -v "NAN" | awk '{s+=$10}END{print s}' )
  temp_RMSE_PRED=$(cat "${fnameVALIDAt2}" | grep -v "NAN" | awk '{print $9^2}'  | awk '{s+=$1}END{print s}' )

  wind_MEAN_SYNOP=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{s+=$6}END{print s}' )
  wind_MEAN_PRED=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{s+=$7}END{print s}' )
  wind_MEAN_ECMWF=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{s+=$8}END{print s}' )
  wind_meanBIAS_PRED=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{s+=$9}END{print s}' )
  wind_meanBIAS_ECMWF=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{s+=$10}END{print s}' )
  wind_RMSE_PRED=$(cat "${fnameVALIDAv10}" | grep -v "NAN" | awk '{print $9^2}'  | awk '{s+=$1}END{print s}' )

  tp1h_MEAN_SYNOP=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{s+=$6}END{print s}' )
  tp1h_MEAN_PRED=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{s+=$7}END{print s}' )
  tp1h_MEAN_ECMWF=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{s+=$8}END{print s}' )
  tp1h_meanBIAS_PRED=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{s+=$9}END{print s}' )
  tp1h_meanBIAS_ECMWF=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{s+=$10}END{print s}' )
  tp1h_RMSE_PRED=$(cat "${fnameVALIDAtp1h}" | grep -v "NAN" | awk '{print $9^2}'  | awk '{s+=$1}END{print s}' )

  npasos=$(cat ${fnameVALIDAt2}| grep -v "NAN"| wc -l )
  if [[ ! -z $npasos && $npasos -gt 0 ]]; then
    echo "${station}" "$lon" "$lat" "${temp_MEAN_SYNOP}" "${temp_MEAN_PRED}" "${temp_MEAN_ECMWF}" "${temp_meanBIAS_PRED}" "${temp_meanBIAS_ECMWF}" | awk '{print $1,$2,$3,$4/'$npasos',$5/'$npasos',$6/'$npasos',$7/'$npasos',$8/'$npasos'}' >> kkt2
  fi

  npasos=$(cat ${fnameVALIDAv10}| grep -v "NAN"| wc -l )
  if [[ ! -z $npasos && $npasos -gt 0 ]]; then
    echo "${station}" "$lon" "$lat" "${wind_MEAN_SYNOP}" "${wind_MEAN_PRED}" "${wind_MEAN_ECMWF}" "${wind_meanBIAS_PRED}" "${wind_meanBIAS_ECMWF}" | awk '{print $1,$2,$3,$4/'$npasos',$5/'$npasos',$6/'$npasos',$7/'$npasos',$8/'$npasos'}' >> kkv10
  fi

  npasos=$(cat ${fnameVALIDAtp1h}| grep -v "NAN"| wc -l )
  if [[ ! -z $npasos && $npasos -gt 0 ]]; then
    echo "${station}" "$lon" "$lat" "${tp1h_MEAN_SYNOP}" "${tp1h_MEAN_PRED}" "${tp1h_MEAN_ECMWF}" "${tp1h_meanBIAS_PRED}" "${tp1h_meanBIAS_ECMWF}" | awk '{print $1,$2,$3,$4/'$npasos',$5/'$npasos',$6/'$npasos',$7/'$npasos',$8/'$npasos'}' >> kktp1h
  fi

done #loop stations

mv kkt2 "${DIR_DATA}"/VALIDA-T2-"${YYYYMMDDHH}".txt
mv kkv10 "${DIR_DATA}"/VALIDA-V10-"${YYYYMMDDHH}".txt
mv kktp1h "${DIR_DATA}"/VALIDA-TP1H-"${YYYYMMDDHH}".txt

#Pinta datos con R
echo "Pinta gráficas"
bash -x ecmwf_pinta_validacion.sh "${YYYYMMDDHH}"

# Se borra fichero de bloqueo y se crea fichero de finalización.
rm "${lockFile}"
touch "${finishedFile}"
echo "$(datePID) - Fin"