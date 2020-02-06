args = commandArgs(trailingOnly=TRUE)
library(ggplot2)
library("maps")
library("mapdata")
library("mapproj")
#library(ggmap)

valida=read.table(args[1])


spainMap <- map_data("world")

data=data.frame(lon=valida[,2],lat=valida[,3],bias=valida[,4], rmse=valida[,5], icao=valida[,1])

pdf(args[2])
ggplot() +
     geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="ivory", col="black") +
	 geom_point(data=data, aes(x=lon, y=lat, size=rmse, color=bias)) +
	 geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
#coord_map(xlim=c(-20,50), ylim=c(30, 60))+
     coord_map("lambert",lat0=30,lat1=65,xlim=c(-20,39), ylim=c(22,75))+
#scale_color_gradient2(midpoint=0, low="royalblue3", mid="white", high="red3")+
     labs(title="Validación: METAR vs METEORED predicciones", x=" " ,y =" ")+
     theme(legend.position = "bottom", legend.direction = "horizontal",
            panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))