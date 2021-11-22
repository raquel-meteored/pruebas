#!/bin/bash 
#Paso a formato csv de los archivos de validación para poder pintarse onthefly con ploty


dirBASE="/home/cep/validacion/Data"

vari="T2 V10 TP12H NIEBLA TPDICO"
fecha=202108

for var in $vari; do

  if [[ "$var" == "NIEBLA" || "$var" == "TPDICO" ]] ; then

    echo station,lon,lat,pc,pod,far,bias,csi > kkcabecera

  else

    echo station,lon,lat,obs,meteored,hres,biasm,biash > kkcabecera

  fi

  cat $dirBASE/mean/MEAN-MONMEAN-$fecha-$var.txt | grep -v "9999" | awk '{printf "%i,%6.3f,%6.3f,%6.3f,%6.3f,%6.3f,%6.3f,%6.3f \n" , $1,$2,$3,$4,$5,$6,$7,$8 }' > kkdatomes
  cat kkcabecera kkdatomes > $dirBASE/mean/MEAN-MONMEAN-$fecha-$var.csv

done

vari="T2 V10 SIMB TP"

for estac in $(seq -w 01000 10000); do

  for var in $vari; do

    if [[ ! -f $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt ]]; then
      continue
    fi

    echo station,lon,lat,obs,meteored,hres,biasm,biash > kkcabecera

    awk '{print $4}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt | cut -c 1-4 > kky
    awk '{print $4}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt | cut -c 5-6 > kkm
    awk '{print $4}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt | cut -c 7-8 > kkd
    awk '{print $4}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt | cut -c 9-10 > kkh

    if [[ "$var" == "SIMB" ]];then
  
      awk '{print  $2 , $3 , $8 , $9 , $10}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt > kkdato
      echo Date,lon,lat,obs,meteored,coincidencia > kkcabecera

    else
 
      awk '{printf "%6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f \n" , $2 , $3 , $6 , $7 , $8 , $9 , $10}' $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".txt > kkdato
      echo Date,lon,lat,obs,meteored,hres,biasm,biash > kkcabecera

    fi

  paste kky kkm kkd kkh kkdato | awk '{print $1"-"$2"-"$3" "$4","$5","$6","$7","$8","$9","$10}' > kktodo
  cat kkcabecera kktodo > $dirBASE/series/serie_"${var}"-"${estac}"_"${fecha}".csv 
  rm kk*
  done

done
