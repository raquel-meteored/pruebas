
args = commandArgs(trailingOnly=TRUE)
library(ggplot2)
#kk=read.table("~/data/VALIDACION/PREDIC-METAR-LEMI-2019102208.txt")
valida=read.table(args[1])
kk=subset(valida,valida[,9]>0)

checkdim=length(kk[,9])
if (checkdim == 0){
    q(save="no")
}

fechaPRE=as.POSIXct(kk[,2]/1000,origin="1970-01-01")
fechaMET=as.POSIXct(kk[,4]/1000,origin="1970-01-01")

leaddia=seq(1,round(max(kk[,9])/24))
leadhora=seq(0,240,24)

minD=min(fechaPRE)
maxD=max(fechaPRE)
minT=round(min(min(kk[,3]),min(kk[,5])))-1
maxT=round(max(max(kk[,3]),max(kk[,5])))+1
minS=-8
maxS=8


pdf(args[2])
i=1
index=which(kk[,9]<leadhora[i+1] & kk[,9]>leadhora[i])
datos=data.frame(fecha=fechaMET[index], metar=kk[index,5], lwr=kk[index,5]-1, upr= kk[index,5]+1,predic=kk[index,3])
biasmean=round(mean(kk[index,6]),3)
breaksec=seq(min(datos$fecha),max(datos$fecha),by="3 hour")
#breakday=seq(min(datos$fecha),max(datos$fecha),by="1 day")

ggplot(data = datos, aes(x = fecha)) +
    geom_point( aes(y=metar),col="orange")+ geom_line(aes(y=metar,color="orange"),show.legend = TRUE)+
    geom_ribbon(aes(y=metar, ymin=lwr, ymax=upr), alpha=.15, fill='orange')+
    geom_point( aes(y=predic),col="deepskyblue")+geom_line(aes(y=predic,color="deepskyblue"),show.legend = TRUE)+
    scale_color_identity(breaks = c("orange", "deepskyblue"), labels = c("METAR", "ECMWF"),  guide = "legend")+
    labs(title=paste("ICAO ",args[3],"SESGO medio=",biasmean,sep = " "), y="Temperatura (ºC)", x=" ") + ylim(minT, maxT)+
#    labs(title=paste("ICAO SESGO medio=",biasmean,sep = " "), y="Temperatura (ºC)", x=" ") + ylim(minT, maxT)+
    scale_y_continuous(limits = c(minT, maxT), breaks = seq(minT, maxT, by = 2))+
#    scale_x_datetime(breaks = breakday, minor_breaks = breaksec, labels= scales::time_format("%A \n %d"), position="top",
#    sec.axis = sec_axis(~ ., name = " ", breaks = breaksec,labels= scales::time_format("%H")))+
    theme_light()+
    theme(legend.position = c(0.8, 0.9), legend.title= element_blank(),
          panel.grid.major = element_line(size = 0.5, linetype = 'solid', colour = "grey3"),
          panel.grid.minor = element_line(size = 0.25, linetype = 'solid',  colour = "grey"))

write.table(biasmean,args[5],col.names=FALSE, row.names=paste("ICAO",args[3] ,sep=" "))