
library("rjson")
library("ggplot2")
library("scales")
library("xtable")

result <- fromJSON(file = "../data/1.json")

kk=data.frame(date=fechaok[t3h],wind=viento[t3h],u=as.numeric(u[t3h]),v=as.numeric(v[t3h]))
kk$x.end <- kk$date + minutes(180)
ggplot(kk, aes(x=date, y=wind)) + geom_line(col="green") + geom_segment( aes(x=date, xend=xend, y = wind, yend= wind+0.5*v), arrow = arrow(length = unit(0.2,"cm")))
ggplot(kk, aes(x=date, y=wind)) + geom_line() + geom_text(aes(angle=-dir+90),label="-->",size=3)


#result$dias[[6]]$dia
#result$dias[[6]]$horas[[2]]$hora
#result$dias[[6]]$horas[[2]]$presion

#cat 1.json | jq '.dias[0].horas[0].hora'

#summary(result$dias[[1]]$horas)
#summary(result$dias)
#En json las max y min sólo las tengo diarias
#result$dias[[1]]$temperatura$maxima

localidad=result$nombre

ndias=dim(summary(result$dias))[1]
nhoras=24
tam=ndias*nhoras
t3h=c( which(hora=="02:00"), which(hora=="05:00"), which(hora=="08:00"), which(hora=="11:00"), which(hora=="14:00"),which(hora=="17:00"),which(hora=="20:00"),which(hora=="23:00"))

dirname=c("N","NE","E","SE","S","SW","W","NW")
dir=seq(0,359,45)
u=c(0,1,1,1,0,-1,-1,-1)
v=c(1,1,0,-1,-1,0,1,1)
dir2=cbind(dirname,dir,u,v)

dia=numeric(tam)
hora=numeric(tam)
fecha=character(tam)

presion=numeric(tam)
temperatura=numeric(tam)
rocio=numeric(tam)
nubosidad=numeric(tam)
viento=numeric(tam)
precipitacion=numeric(tam)
humedad=numeric(tam)
dir=numeric(tam)
u=numeric(tam)
v=numeric(tam)

k=0

for (dd in 1:ndias) {
 nhoras=dim(summary(result$dias[[dd]]$horas))[1]
 for (hh in 1:nhoras) {
         k=k+1	 
	 dia[k]=result$dias[[dd]]$dia
	 hora[k]=result$dias[[dd]]$horas[[hh]]$hora
	 fecha[k]=paste(dia[k],hora[k])

	 presion[k]=result$dias[[dd]]$horas[[hh]]$presion
	 temperatura[k]=result$dias[[dd]]$horas[[hh]]$temperatura$valor
	 precipitacion[k]=result$dias[[dd]]$horas[[hh]]$precipitacion$valor
	 rocio[k]=result$dias[[dd]]$horas[[hh]]$temperatura$rocio
	 nubosidad[k]=result$dias[[dd]]$horas[[hh]]$nubosidad
	 humedad[k]=result$dias[[dd]]$horas[[hh]]$humedad
	 viento[k]=result$dias[[dd]]$horas[[hh]]$viento$velocidad
         dir[k]=subset(dir2[,2], dir2[,1]==result$dias[[dd]]$horas[[hh]]$viento$direccion)
         u[k]=subset(dir2[,3], dir2[,1]==result$dias[[dd]]$horas[[hh]]$viento$direccion)
         v[k]=subset(dir2[,4], dir2[,1]==result$dias[[dd]]$horas[[hh]]$viento$direccion)
         	 
 }
}

fechaok=as.POSIXct(fecha, format="%Y%m%d %H:%M", tz= "GMT")
#get position of each 3h
t3h=sort(c(which(hora=="02:00"), which(hora=="05:00"), which(hora=="08:00"), which(hora=="11:00"), which(hora=="14:00"),which(hora=="17:00"),which(hora=="20:00"),which(hora=="23:00")))
t12h=sort(c(which(hora=="02:00"), which(hora=="14:00")))
t24h=which(hora=="14:00")


png("uv.png")
tstep=seq(1,48,6)
par(mfrow=c(2,4))
for (i in tstep) { 
    plot(c(0,u[i]),c(0,v[i]),xlim=c(-1,1),ylim=c(-1,1),type="l", ylab="", xlab="",xaxt= "n", yaxt="n", main=paste(dir[i]," H=", hora[i],sep=""),col="red")
    axis(2, at=c(-1,0,1),labels=c("SW","W","NW"), col.axis="red", las=2)
    axis(4, at=c(-1,0,1),labels=c("SE","E","NE"), col.axis="red", las=2)
    axis(1, at=c(0),labels=c("N"), col.axis="red", las=2)
    axis(3, at=c(0),labels=c("S"), col.axis="red", las=2)
}

png("dir.png")
plot(fechaok,dir)

png("presion.png")
plot(fechaok[t3h],presion[t3h],type="h",col="purple",xlab="Fecha",ylab="Presion", main="Presion (hPa)")


png("precipitacion.png")
plot(fechaok,precipitacion,type="h",col="blue",xlab="Fecha",ylab="Precipitacion",main="Precipitacion (mm)")

png("nubosidad.png")
plot(fechaok,nubosidad,type="l",col="red",xlab="Fecha",ylab=" ",main="Nubosidad (%)")

png("temperatura.png")
plot(fechaok,temperatura,type="l",col="red",xlab="Fecha",ylab="Temperatura", main="Temperatura (ºC)")

png("rocio.png")
plot(fechaok,rocio,type="l",col="red",xlab="Fecha",ylab="Temperatura", main="Punto de Rocio (ºC)")

png("humedad.png")
plot(fechaok,nubosidad,type="l",col="red",xlab="Fecha",ylab=" ",main="Humedad (%)")


png("viento.png")
plot(fechaok,viento,type="l",col="green",xlab="Fecha",ylab="Velocidad", main="Velocidad del viento")

dev.off()
