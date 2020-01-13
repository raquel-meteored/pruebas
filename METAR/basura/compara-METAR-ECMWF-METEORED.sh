#!/bin/bash


pathECMWF=/home/ecmwf

fechaINI=12040000
fechaPRED=120403001

fileECMWF=$pathECMWF/A1D$fechaINI$fechaPRED

tempECMWF=$(grib_get -l ${lat},${lon},1 -w shortName=2t ${fileECMWF})
dateECMWF=$(grib_get -l ${lat},${lon},1 -w shortName=2t -P dataDate,step ${fileECMWF})
echo $tempECMWF
