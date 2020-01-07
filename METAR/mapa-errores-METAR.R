args = commandArgs(trailingOnly=TRUE)
library(ggplot2)
library("maps")
library("mapdata")
#library(ggmap)

valida=read.table(args[1])
some.eu.countries <- c("Spain")
spainMap <- map_data("worldHires",region = some.eu.countries)
#map <- get_map(location = 'Europe', zoom = 4)

data=data.frame(lon=valida[,2],lat=valida[,3],bias=valida[,4], rmse=valida[,5], icao=valida[,1])
li=c(-6,6)
br<-seq(-6,6,2)
la=br

pdf(args[2])
ggplot() +
#	    ggmap(map)+
	    geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="lightgrey") +
	#	geom_point(data=data, aes(x=lon, y=lat), size=rmse+0.2, col="black") +
	    geom_point(data=data, aes(x=lon, y=lat, size=rmse, color=bias)) +
	    geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=1.5) +
#	    scale_colour_distiller(palette = "RdBu") +
#	    scale_fill_gradientn(name = "Title", limits = li, labels = la, breaks = br, palette = "RdBu")+
		#scale_colour_gradientn(name = "Title", limits = li, labels = la, breaks = br, colors=c("red","white","blue"))+
	    scale_color_gradient2(midpoint=0, low="blue", mid="white", high="red")+
	    theme(legend.position = "bottom", legend.direction = "horizontal",
			  panel.background = element_blank(), panel.border = element_rect(linetype = "solid", fill = NA))