#!/bin/bash
#Comprobaciones de direcciones

idtiempo=$1


jq '.' ./JSON/$idtiempo.json | grep "direccion" > kk
jq '.' ./OTF/$idtiempo.json | grep "direccion" > kk2

diff kk kk2 > ./comparaciones/diff_dir_$idtiempo
paste kk kk2 > ./comparaciones/paste_dir_$idtiempo
