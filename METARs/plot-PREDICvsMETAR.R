
args = commandArgs(trailingOnly=TRUE)
#kk=read.table("~/data/VALIDACION/PREDIC-METAR-LEMI-2019102208.txt")
kk=read.table(args[1])
fechaPRE=as.POSIXct(kk[,2]/1000,origin="1960-01-01")
fechaMET=as.POSIXct(kk[,4]/1000,origin="1960-01-01")

minD=min(fechaPRE)
maxD=max(fechaPRE)
minT=min(min(kk[,3]),min(kk[,5]))-1
maxT=max(max(kk[,3]),max(kk[,5]))+1
minS=-5
maxS=5

pdf(args[2])
plot(fechaMET,kk[,6],type="b",col="darkgrey",yaxt="n",ylim=c(minS,maxS),xlim=c(minD,maxD),yaxt="n", ylab="", xlab="",lwd=2,pch=2, main=paste("ICAO ",args[3],sep = " "))
rect(minD,-1,maxD,1,col="darkseagreen1",border=FALSE,density=30)
par(new=TRUE)
plot(fechaMET,kk[,6],type="b",col="darkgrey",yaxt="n",ylim=c(minS,maxS),xlim=c(minD,maxD),yaxt="n", ylab="", xlab="",lwd=2,pch=2)
abline(h=0,lty=2,col="grey")
abline(h=-1,lty=2,col="grey")
abline(h=1,lty=2,col="grey")
axis(4,col="darkgrey",col.axis="darkgrey")
par(new=TRUE)
plot(fechaPRE,kk[,3],type="b",col="deepskyblue",ylim=c(minT,maxT),ylab="Temperatura (C)",xlab="Fecha",xlim=c(minD,maxD),lwd=2)
par(new=TRUE)
plot(fechaMET,kk[,5],type="b",col="darkorange",ylim=c(minT,maxT),xlim=c(minD,maxD),yaxt="n", ylab="", xlab="",lwd=2)
par(new=TRUE)
legend("top",c("ECMWF","METAR","SESGO"),col=c("deepskyblue","darkorange","darkgrey"),lty=c(1,1,1),horiz=TRUE,lwd=2)