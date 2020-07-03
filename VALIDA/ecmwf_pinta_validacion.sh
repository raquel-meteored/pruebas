#!/bin/bash
####################################################################################
### Pinta mapas con la validación usando datos SYNOP
### Creado en 07-2020

# Raquel Lorente Plazas <raquel@meteored.com>
# Marcos Molina Cano <marcos@meteored.com>
# Juan Sanchez Segura <jsanchez@meteored.com>
# Guillermo Ballester Valor <gbv@ogimet.com>

###################################################################################
DIR_DATA=/home/raquel/Data/SYNOP
DIR_PLOT=/home/raquel/Plots/SYNOP
AAAAMMDDHH=$1
fileinT2=${DIR_DATA}/VALIDA-T2-${AAAAMMDDHH}.txt
fileinV10=${DIR_DATA}/VALIDA-V10-${AAAAMMDDHH}.txt
fileinTP1h=${DIR_DATA}/VALIDA-TP1H-${AAAAMMDDHH}.txt
plotT2=${DIR_PLOT}/VALIDA-T2
plotV10=${DIR_PLOT}/VALIDA-V10
plotTP1h=${DIR_PLOT}/VALIDA-TP1h

R --vanilla --args "${fileinT2}" "${fileinV10}" "${fileinTP1h}" "${plotT2}" "${plotV10}" "${plotTP1h}" << EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)
  library("maps")
  library("mapdata")
  library("mapproj")
 #library(ggmap)

  T2=read.table(args[1])
  dataT2=data.frame(lon=T2[,2], lat=T2[,3],temp=T2[,4],tempPRED=T2[,5], tempECMWF=T2[,6],tempbiasPRED=T2[,7], tempbiasECMWF=T2[,8], station=T2[,1])
  V10=read.table(args[2])
  dataV10=data.frame(lon=V10[,2], lat=V10[,3],vv=V10[,4], vvPRED=V10[,5], vvECMWF=V10[,6],vvbiasPRED=V10[,7], vvbiasECMWF=V10[,8], station=V10[,1])
  TP1h=read.table(args[3])
  dataTP1h=data.frame(lon=TP1h[,2], lat=TP1h[,3],tp=TP1h[,4], tpPRED=TP1h[,5], tpECMWF=TP1h[,6], tpbiasPRED=TP1h[,7], tpbiasECMWF=TP1h[,8], station=TP1h[,1])

  spainMap <- map_data("world")

  pdf(paste(args[4],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=temp), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,40))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas SYNOP", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[5],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vv), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas SYNOP", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[6],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tp), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas SYNOP", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[4],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,40))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas 2m  METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[5],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Velocidad del viento METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[6],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Precipitación METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[4],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,40))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas 2m ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[5],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Velocidad del viento ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[6],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Precipitación ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[4],'_BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempbiasPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias Temp. 2m METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[5],'_BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvbiasPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias Viento 10 m METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[6],'BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpbiasPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias precipitación METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[4],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempbiasECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias Temp. 2m ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[5],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvbiasECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias viento a 10 m ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(paste(args[6],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpbiasECMWF), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Bias precipitación ECMWF", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

dev.off()
EOF

exit

for hora in $(seq -w 0 23);do
  fechaSYNOP=$(cat "$fnameSYNOP" | awk -F "," '{if ($5=="'$hora'") print $2$3$4$5$6}' | head -1)
  filein=prueba-$fechaSYNOP
  plotTemp=/home/raquel/Plots/SYNOP/MAPA-temp-SYNOP-$fechaSYNOP.pdf
  plotPrec=/home/raquel/Plots/SYNOP/MAPA-prec-SYNOP-$fechaSYNOP.pdf
  plotTempPRED=/home/raquel/Plots/SYNOP/MAPA-temp-PRED-$fechaSYNOP.pdf
  plotPrecPRED=/home/raquel/Plots/SYNOP/MAPA-prec-PRED-$fechaSYNOP.pdf
  plotTempBIAS=/home/raquel/Plots/SYNOP/MAPA-temp-BIAS-$fechaSYNOP.pdf
  plotPrecBIAS=/home/raquel/Plots/SYNOP/MAPA-prec-BIAS-$fechaSYNOP.pdf

R --vanilla --args "${filein}" "${plotTemp}" "${plotPrec}" "${plotTempPRED}" "${plotPrecPRED}" "${plotTempBIAS}" "${plotPrecBIAS}" << EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)
  library("maps")
  library("mapdata")
  library("mapproj")
 #library(ggmap)

  valida=read.table(args[1])
  data=data.frame(lon=valida[,2], lat=valida[,3],temp=valida[,5], precip=valida[,6], tempPRED=valida[,7], precipPRED=valida[,8] ,tempBIAS=valida[,9], precipBIAS=valida[,10], station=valida[,1])
  spainMap <- map_data("world")

  pdf(args[2])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=temp), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-35,35))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas SYNOP", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[3])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=precip), shape=21, size=2, col="black") +
         scale_fill_gradient2(low="white", mid="cyan", high="darkblue", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Precipitación SYNOP", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[4])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=tempPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-35,35))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Temperaturas METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[5])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=precipPRED), shape=21, size=2, col="black") +
         scale_fill_gradient2(low="white", mid="cyan", high="darkblue", limits=c(0,10))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Precipitación METEORED", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[6])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=tempBIAS), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Validación: Temperaturas", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

  pdf(args[7])
  ggplot() +
         geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="grey") +
	       geom_point(data=data, aes(x=lon, y=lat, fill=precipBIAS), shape=21, size=2, col="black") +
         scale_fill_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3", limits=c(-5,5))+
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(30,65))+
         labs(title="Validación: Precipitación", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

dev.off()
EOF

#rm kkprueba*
#for station in $synopID; do
cat $filein | awk '{if ($1=='08434') print $0}' >> kkestacion-08434
cat $filein | awk '{if ($1=='08220') print $0}' >> kkestacion-08220

#done
done

R --vanilla --args kkestacion-08434  tsestación-08434.pdf << EOF
  args = commandArgs(trailingOnly=TRUE)
  library(ggplot2)

  valida=read.table(args[1])
  data=data.frame( fecha=valida[,4], precipSYNOP=valida[,6], precipPRED=valida[,8] )

  pdf(args[2])
  ggplot() +
	       geom_point(data=data, aes(x=fecha, y=precipSYNOP),  size=2, col="black") +
	       geom_point(data=data, aes(x=fecha, y=precipPRED),  size=2, col="blue") +
         labs(title="Validación: Precipitación", x=" " ,y =" ")+
         theme(legend.position = "bottom", legend.direction = "horizontal",
               panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

EOF
