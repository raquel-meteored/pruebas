#!/bin/bash
#script para comprobar las horas del envío del pdf

# Formato de fecha
fechaUTC=$(date -u +%Y-%m-%d\ %H:%M:%S)

filein=/home/cep/clientes-zonahoraria.csv
day_des=$1
pasada=$2
fecha=$(date -u +%Y%m%d --date="${day_des} days")
AAAAMMDDHH=${fecha}${pasada} 

while IFS=, read -r IDnum lon lat alt zoneinfo name titular email completo reducido tabla
do  
   fechaHOY=$(TZ="$zoneinfo" date +%d/%m/%Y)
   horaHOY=$(TZ="$zoneinfo" date +%H)
   start_day=$(date --rfc-3339=date)

  #Se envían dos emails; uno por cada pasada
   if [[ "$pasada" == 12 ]]; then  #En el cron se activará a las 1-2UTC, horaHOY=3 está en local
   #fecha_ini_predic=$(date --rfc-3339=date "-d -1 day")T"$pasada":00h
      if [[ "$horaHOY" -ge 6 ]] && [[ "$horaHOY" -lt 18 ]]; then  
	hora_envio=18:00:00
	pred_valida="mañana"
	fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")
      else
	hora_envio=06:00:00
	pred_valida="hoy"
	if [[ "$horaHOY" -ge 18 ]]; then
	  fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")    
	else
       	  fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y)
	fi	
	#desfase=$(printf "%.0f" $(TZ=${zoneinfo} date +%z))
	#if [[ "${desfase}" -ge 0 ]]; then
       	#  fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y)
	#else
	#  fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")
        #fi
      fi
  fi

  if [[ "$pasada" == '00' ]]; then #En el cron se activará a las 13-14UTC, horaHOY=15
    #fecha_ini_predic=$(date --rfc-3339=date)T"$pasada":00h

    if [[ "$horaHOY" -gt 6 ]] && [[ "$horaHOY" -le 18 ]]; then
      hora_envio=18:00:00
      pred_valida="mañana"
      fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")
    else
      start_day=$(date --rfc-3339=date "-d +1 day")
      hora_envio=06:00:00
      fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y)
      pred_valida="hoy"
    fi
 
  fi
  #Cambia formato de la fecha a la que empieza la predicción
  fecha_valida_archivo=$(date --date="${fecha_valida}" +%d%m%Y )
  fecha_valida_asunto=$(date --date="${fecha_valida}" +%d/%m/%Y )

  #Fecha a la que se manda el email con la predicción
  desfase=$(TZ=${zoneinfo} date +%:z)
  start_time="${start_day}T${hora_envio}${desfase}"
  
  echo "UTC:$fechaUTC LOCAL:$fechaHOY $horaHOY ENVIO:${start_time} ASUNTO:${fecha_valida_asunto} ${pred_valida} $zoneinfo $name" >> chequeo-envio-pdf-$AAAAMMDDHH.txt 	

done < "$filein"	
