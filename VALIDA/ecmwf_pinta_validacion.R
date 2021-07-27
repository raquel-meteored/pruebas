#!/bin/bash
####################################################################################
### Pinta mapas con la validación usando datos SYNOP
### creados con ecmwf_valida_SYNOP
### Creado en 07-2020

# Raquel Lorente Plazas <raquel@meteored.com>
# Marcos Molina Cano <marcos@meteored.com>
# Juan Sanchez Segura <jsanchez@meteored.com>
# Guillermo Ballester Valor <gbv@ogimet.com>

###################################################################################

args = commandArgs(trailingOnly=TRUE)
library(ggplot2)
library("maps")
library("mapdata")
library("mapproj")
library("RColorBrewer")
 #library(ggmap)

#Lee los archivos con la info
T2=read.table(args[1])
V10=read.table(args[2])
TP1h=read.table(args[3])

#Crea los data frame
dataT2=data.frame(lon=T2[,2], lat=T2[,3],temp=T2[,4],tempPRED=T2[,5], tempECMWF=T2[,6],tempbiasPRED=T2[,7], tempbiasECMWF=T2[,8], station=T2[,1])
dataV10=data.frame(lon=V10[,2], lat=V10[,3],vv=V10[,4], vvPRED=V10[,5], vvECMWF=V10[,6],vvbiasPRED=V10[,7], vvbiasECMWF=V10[,8], station=V10[,1])
dataTP1h=data.frame(lon=TP1h[,2], lat=TP1h[,3],tp=TP1h[,4], tpPRED=TP1h[,5], tpECMWF=TP1h[,6], tpbiasPRED=TP1h[,7], tpbiasECMWF=TP1h[,8], station=TP1h[,1])

#Seleccionamos la región del mundo a pintar
worldMap <- map_data("world")
coordMap=coord_map("lambert",lat0=30,lat1=65,xlim=c(-12,5), ylim=c(34,45))

tema=theme( legend.direction = "horizontal", legend.position = c(0.5, 0.05),
            legend.background = element_rect(fill="white",  size=0.2, linetype="solid", colour ="black"),
            legend.title = element_text(size=6), legend.text = element_text(size=6),
            legend.key = element_rect(fill = "white", colour = "white" ,  size=0.2),
            panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))

#Paletas
paletaT2=scale_fill_gradientn(colours=rev(brewer.pal(9,"Spectral")),name="Temp. (C)",limits=c(-30,30))
paletaV10=scale_fill_gradientn(colours=brewer.pal(9,"Purples"),name="Veloc. Viento (m/s)",limits=c(0,12))
paletaPR=scale_fill_gradientn(colours=brewer.pal(9,"Blues"),name="Precip. (mm)",limits=c(0,100))
paletaBIAS=scale_fill_gradientn(colours=rev(brewer.pal(9,"RdBu")),limits=c(-5,5))

pdf(paste(args[4],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=temp), shape=21, size=2) +
	       paletaT2+
         coordMap+
         labs(title="Temperaturas SYNOP", x=" " ,y =" ",  fill = "Temp. (C)")+
         tema

pdf(paste(args[5],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vv), shape=21, size=2) +
	       paletaV10 +
         coordMap +
         labs(title="Velocidad del viento a 10m SYNOP", x=" " ,y =" ")+
         tema

pdf(paste(args[6],'-SYNOP.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tp), shape=21, size=2) +
         paletaPR+
         coordMap+
         labs(title="Precipitación SYNOP", x=" " ,y =" ") +
         tema

pdf(paste(args[4],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempPRED), shape=21, size=2) +
         paletaT2+
         coordMap+
         labs(title="Temperaturas 2m  METEORED", x=" " ,y =" ")+
         tema

pdf(paste(args[5],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvPRED), shape=21, size=2) +
         paletaV10+
         coordMap+
         labs(title="Velocidad del viento METEORED", x=" " ,y =" ")+
         tema

pdf(paste(args[6],'-PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpPRED), shape=21, size=2) +
         paletaPR+
         coordMap+
         labs(title="Precipitación METEORED", x=" " ,y =" ")+
         tema

pdf(paste(args[4],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempECMWF), shape=21, size=2) +
	       paletaT2 +
         coordMap+
         labs(title="Temperaturas 2m ECMWF", x=" " ,y =" ")+
         tema

pdf(paste(args[5],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvECMWF), shape=21, size=2, col="black") +
         paletaV10+
         coordMap+
         labs(title="Velocidad del viento ECMWF", x=" " ,y =" ")+
         tema

pdf(paste(args[6],'-ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpECMWF), shape=21, size=2, col="black") +
         paletaPR+
         coordMap+
         labs(title="Precipitación ECMWF", x=" " ,y =" ")+
         tema

pdf(paste(args[4],'_BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempbiasPRED), shape=21, size=2, col="black") +
	       paletaBIAS +
	       coordMap+
         labs(title="Bias Temp. 2m METEORED", x=" " ,y =" ", fill = "Temp. (C)")+
         tema

pdf(paste(args[5],'_BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvbiasPRED), shape=21, size=2) +
	       paletaBIAS +
	       coordMap+
         labs(title="Bias Viento 10 m METEORED", x=" " ,y =" ", fill = "Veloc. Viento (m/s)")+
         tema

pdf(paste(args[6],'BIAS_PRED.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpbiasPRED), shape=21, size=2, col="black") +
         paletaBIAS +
         coordMap+
         labs(title="Bias precipitación METEORED", x=" " ,y =" ", fill = "Precip. (mm)")+
         tema

pdf(paste(args[4],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataT2, aes(x=lon, y=lat, fill=tempbiasECMWF), shape=21, size=2, col="black") +
	       paletaBIAS +
	       coordMap+
         labs(title="Bias Temp. 2m ECMWF", x=" " ,y =" ", fill = "Temp. (C)")+
         tema

pdf(paste(args[5],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataV10, aes(x=lon, y=lat, fill=vvbiasECMWF), shape=21, size=2, col="black") +
	       paletaBIAS +
	       coordMap+
         labs(title="Bias Viento 10 m ECMWF", x=" " ,y =" ", fill = "Veloc. Viento (m/s)")+
         tema

  pdf(paste(args[6],'_BIAS_ECMWF.pdf',sep=""))
  ggplot() +
         geom_map(data=worldMap, aes(map_id=region), map=worldMap, fill="ivory", col="grey") +
	       geom_point(data=dataTP1h, aes(x=lon, y=lat, fill=tpbiasECMWF), shape=21, size=2, col="black") +
         paletaBIAS +
         coord_map("lambert",lat0=30,lat1=65,xlim=c(-12,5), ylim=c(34,45))+
         labs(title="Bias precipitación ECMWF", x=" " ,y =" ", fill = "Precip. (mm)")+
         tema

dev.off()
q()
