args = commandArgs(trailingOnly=TRUE)
library(ggplot2)

valida=read.table(args[1])
icao=args[3]
lon=args[4]
lat=args[5]

fechaPRE=as.POSIXct(valida[,2]/1000,origin="1970-01-01")
fechaMET=as.POSIXct(valida[,4]/1000,origin="1970-01-01")
tempPRE=valida[,3]
tempMET=valida[,5]

#Estadístico
sesgo=tempPRE-tempMET
rmse=round(sqrt(mean((sesgo)**2)),2)
mae=round(mean(abs(sesgo)),2)
biasmean=round(mean(sesgo),2)
maxmae=round(max(abs(sesgo)),2)

write.table(cbind(lon, lat, biasmean,rmse,mae,maxmae),args[6],col.names=FALSE, row.names=args[3])
datos=data.frame(fecha=fechaMET, metar=tempMET, lwr=tempMET-0.5, upr= tempMET+0.5, predic=tempPRE)

#Limites
minT=round(min(min(tempPRE),min(tempMET)))-1
maxT=round(max(max(tempPRE),max(tempMET)))+1
minD=min(fechaPRE)
maxD=max(fechaPRE)
minS=-8
maxS=8
breaksec=seq(min(datos$fecha),max(datos$fecha),by="3 hour")
#breakday=seq(min(datos$fecha),max(datos$fecha),by="1 day")

png(args[2])
ggplot(data = datos, aes(x = fecha)) +
    geom_point( aes(y=metar),col="orange")+ geom_line(aes(y=metar,color="orange"),show.legend = TRUE)+
    geom_ribbon(aes(ymin=lwr, ymax=upr), alpha=.15, fill='orange')+
    geom_point( aes(y=predic),col="deepskyblue") + geom_line(aes(y=predic,color="deepskyblue"),show.legend = TRUE) +
    scale_color_identity(breaks = c("orange", "deepskyblue"), labels = c("METAR", "ECMWF"),  guide = "legend") +
    labs(title=paste("ICAO ",icao,"SESGO=",biasmean, "RMSE=",rmse, "MAE=",mae, sep = " "), y="Temperatura (ºC)", x=" ") +
#    labs(title=paste("ICAO SESGO medio=",biasmean,sep = " "), y="Temperatura (ºC)", x=" ") + ylim(minT, maxT)+
    scale_y_continuous(limits = c(minT, maxT), breaks = seq(minT, maxT, by = 2))+
#    scale_x_datetime(breaks = breakday, minor_breaks = breaksec, labels= scales::time_format("%A \n %d"), position="top",
#    sec.axis = sec_axis(~ ., name = " ", breaks = breaksec,labels= scales::time_format("%H")))+
    theme_light()+
    theme(legend.position = c(0.8, 0.9), legend.title= element_blank(),
          panel.grid.major = element_line(size = 0.5, linetype = 'solid', colour = "grey3"),
          panel.grid.minor = element_line(size = 0.25, linetype = 'solid',  colour = "grey"))


