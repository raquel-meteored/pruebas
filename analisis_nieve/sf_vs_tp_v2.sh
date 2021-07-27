#!/bin/bash

#Comparamos snowfall y total precipitation para diferentes tipos de precipitación


file=ECMWF_2021050700_001.grb
#grib_get_data -w shortName=ptype $file -p step | awk '{print $3}' > ptype
#grib_get_data -w shortName=sf $file | awk '{print $3}' > sf
#grib_get_data -w shortName=tp $file | awk '{print $3}' > tp

paste ptype tp sf | awk '{print $0,$2-$3}' | awk '{if ($2>0) print $0,$4/$2 }' > ecmwf_2021050700_001_tpsf.txt

cp ecmwf_2021050700_001_tpsf.txt kk

cat kk | awk '{if ($1==3) print $0}' > diff-supercooled
cat kk | awk '{if ($1==5) print $0}' > diff-snow
cat kk | awk '{if ($1==6) print $0}' > diff-wetsnow
cat kk | awk '{if ($1==7) print $0}' > diff-rainsnow

ndiffsnow=$(cat diff-snow | wc -l)
ndiffrainsnow=$(cat diff-rainsnow | wc -l)
ndiffwetsnow=$(cat diff-wetsnow | wc -l)

echo $ndiffsnow $ndiffwetsnow $ndiffrainsnow > puntos-error_v2.txt
