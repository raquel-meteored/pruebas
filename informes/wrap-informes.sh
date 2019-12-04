#!/bin/bash

pathBASE=/home/raquel/repos/pruebas/informes
input=$pathBASE/ciudades.txt
while read -r geonameId lon lat alt zoneinfo name
do
  echo $geonameId $lon $lat $alt $zoneinfo $name
  time ./genera-informe.sh "$geonameId" "$name" "$zoneinfo" "$lon" "$lat" "$alt"
  mv prueba.pdf informe-$name.pdf
  exit
done < "$input"
