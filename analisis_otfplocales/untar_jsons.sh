#!/bin/bash


for file in $(ls ./JSON/json_*.tar.gz); do

  tar -xvf $file 
  
  for i in $(seq 1 99);do
    mv ${i}*.json ./JSON
  done

done	
