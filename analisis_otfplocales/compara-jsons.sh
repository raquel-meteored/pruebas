#/bin/bash

cd ./OTF
path=/home/raquel/Pruebas/analisis_otfplocales
for file in *.json; do
  
  diff -y <(jq . $path/JSON/$file) <(jq . $path/OTF/$file) | grep "|" | grep -v "utime" | grep -v "salida" | grep -v "puesta" | grep -v "radiacion" | grep -v "_luz" | grep -v "cubierto" |grep -v "despejado" | grep -v "medio" >> ../kkdiffall 

done
