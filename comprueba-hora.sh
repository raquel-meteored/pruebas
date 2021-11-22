#/bin/bash
#script para comprobar las horas del envío del pdf

# Formato de fecha
function datePID() {
   echo "$(date -u +%Y-%m-%d\ %H:%M:%S) UTC"
}

filein=/home/cep/clientes-zonahoraria.csv

while IFS=, read -r IDnum lon lat alt zoneinfo name titular email completo reducido tabla
do  
   fechaHOY=$(TZ="$zoneinfo" date +%d/%m/%Y)
   horaHOY=$(TZ="$zoneinfo" date +%H)
  
  #Se envían dos emails; uno por cada pasada
    if [ "$pasada" == '12' ]; then  #En el cron se activará a las 1-2UTC, horaHOY=3 está en local
	    #fecha_ini_predic=$(date --rfc-3339=date "-d -1 day")T"$pasada":00h

      if [ "$horaHOY" -ge 6 ] && [ "$horaHOY" -lt 18 ]; then
	hora_envio=18:00:00
	fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")
	pred_valida="mañana"
      else
	hora_envio=06:00:00
	pred_valida="hoy"
	desfase=$(printf "%.0f" $(TZ=${zoneinfo} date +%z))
	if [[ "${desfase}" -ge 0 ]]; then
											          fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y)
												        else
														        fecha_valida=$(TZ="$zoneinfo" date +%m/%d/%Y "-d +1 day")
															      fi

															           fi

																     fi


  desfase=$(printf "%.0f" $(TZ=${zoneinfo} date +%z))
  echo "$(datePID) $fecha $desfase $zoneinfo $name" >> chequeo-envio-pdf.txt 	
done < "$filein"	
