#!/bin/bash

#Comparamos snowfall y total precipitation para diferentes tipos de precipitación


file=ECMWF_2021050700_001.grb
grib_get_data -w shortName=ptype $file | awk '{print $3}' > ptype
grib_get_data -w shortName=sf $file | awk '{print $3}' > sf
grib_get_data -w shortName=tp $file | awk '{print $3}' > tp


paste ptype tp sf > kk

cat kk | awk '{if ($1==0) print $0}' > ptype-norain
cat kk | awk '{if ($1==1) print $0}' > ptype-rain
cat kk | awk '{if ($1==3) print $0}' > ptype-supercooled
cat kk | awk '{if ($1==5) print $0}' > ptype-snow
cat kk | awk '{if ($1==6) print $0}' > ptype-wetsnow
cat kk | awk '{if ($1==7) print $0}' > ptype-rainsnow

cat ptype-snow | awk '{if ($2>0) print $1,100*($2-$3)/$2,$2,$3}' | awk '{if ($2>5 || $2<-5) print $0}' > diff-snow
cat ptype-wetsnow | awk '{if ($2>0) print $1,100*($2-$3)/$2,$2,$3}' | awk '{if ($2>5 || $2<-5) print $0}' > diff-wetsnow 
cat ptype-rainsnow | awk '{if ($2>0) print $1,100*($2-$3)/$2,$2,$3}' | awk '{if ($2>5 || $2<-5) print $0}' > diff-rainsnow 


nwetsnow=$(cat ptype-wetsnow | wc -l)
nrainsnow=$(cat ptype-rainsnow | wc -l)
nsnow=$(cat ptype-snow | wc -l)
ndiffsnow=$(cat diff-snow | wc -l)
ndiffrainsnow=$(cat diff-rainsnow | wc -l)
ndiffwetsnow=$(cat diff-wetsnow | wc -l)

echo $nsnow $nwetsnow $nrainsnow $ndiffsnow $ndiffwetsnow $ndiffrainsnow  | awk '{print "snow",100*$4/$1,"wetsnow",100*$5/$2,"rainsnow",100*$6/$3}' > puntos-error.txt
