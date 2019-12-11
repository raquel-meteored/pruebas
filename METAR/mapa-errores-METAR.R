args = commandArgs(trailingOnly=TRUE)
library(ggplot2)
library("maps")
library("mapdata")

valida=read.table(args[1])
some.eu.countries <- c("Spain")
spainMap <- map_data("worldHires",region = some.eu.countries)

data=data.frame(lon=valida[,2],lat=valida[,3],bias=valida[,4], rmse=valida[,5], icao=valida[,1])

pdf(args[2])
ggplot() +
	    geom_map(data=spainMap, aes(map_id=region), map=spainMap, fill="lightgrey") +
	    geom_point(data=data, aes(x=lon, y=lat, size=rmse, color=bias)) +
	    geom_text(data=data, aes(x=lon, y=lat+0.1, label=icao), size=2) +
	    scale_colour_distiller(palette = "RdBu") +
	    theme_void()