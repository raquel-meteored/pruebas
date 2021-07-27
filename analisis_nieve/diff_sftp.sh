#!/bin/bash 
#Compara las diferencias entre sf y tp cuando sólo hay sf


pasada=2021050700

grib_copy -w shortName=tp/sf/ptype ./datos/ECMWF_${pasada}_001.grb kkselvar.grb

grib_to_netcdf -D NC_FLOAT -o ./datos/ECMWF_${pasada}_001_sftp.nc kkselvar.grb

cdo -setvals,5,0 -setrtomiss,0,4 -setrtomiss,6,8 -selvar,ptype ./datos/ECMWF_${pasada}_001_sftp.nc kkmasksf.nc

cdo expr,'diff=tp-sf;sf;tp;ptype' -sub ./datos/ECMWF_${pasada}_001_sftp.nc kkmasksf.nc ./results/ECMWF_${pasada}_sfdiff.nc

