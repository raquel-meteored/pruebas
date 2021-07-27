#!/bin/bash
# Nombre del script.
scriptName=$(basename "$0")

# Formato de fecha para el fichero .log.
function datePID {
	  echo "$(date -u +%Y/%m/%d\ %H:%M:%S) UTC [$$]"
  }

  ping -q -w1 -c1 google.com &>/dev/null &&  echo online $(datePID) || echo offline $(datePID)
