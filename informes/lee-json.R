
library("rjson")

result <- fromJSON(file = "../data/1.json")

#result$dias[[6]]$dia
#result$dias[[6]]$horas[[2]]$hora
#result$dias[[6]]$horas[[2]]$presion

#cat 1.json | jq '.dias[0].horas[0].hora'

#summary(result$dias[[1]]$horas)
#summary(result$dias)
#En json las max y min sólo las tengo diarias
#result$dias[[1]]$temperatura$maxima

localidad=result$nombre

ndias=2
nhoras=24
tam=ndias*nhoras

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

k=0
for (dd in 1:ndias) {
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
	 
	 
 }
}

fechaok=as.POSIXct(fecha, format="%Y%m%d %H:%M", tz= "GMT")

png("presion.png")
plot(fechaok,presion,type="h",col="purple",xlab="Fecha",ylab="Presion", main="Presion (hPa)")


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
