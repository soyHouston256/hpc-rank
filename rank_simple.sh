#!/bin/bash

# Script simplificado para pruebas rápidas
# Uso: ./rank_simple.sh [repeticiones]

REPETICIONES=${1:-3}
OUTPUT="resultados_simple.txt"

echo "Compilando..."
mpicxx -o rank main.cpp -std=c++17 || exit 1

echo "P,N,Ejecucion,Computo,Comunicacion" > $OUTPUT

# Solo números de procesos que son cuadrados perfectos: 1, 4, 16
for P in 1 4 16; do
    for N in 10000 30000 50000 80000 100000; do
        echo "Ejecutando P=$P, N=$N..."
        
        for i in $(seq 1 $REPETICIONES); do
            result=$(mpiexec -n $P ./rank $N 2>&1)
            
            if echo "$result" | grep -q "Ejecucion:"; then
                ejec=$(echo "$result" | grep "Ejecucion:" | awk '{print $2}')
                comp=$(echo "$result" | grep "Computo:" | awk '{print $2}')
                comm=$(echo "$result" | grep "Comunicacion:" | awk '{print $2}')
                echo "$P,$N,$ejec,$comp,$comm" >> $OUTPUT
                echo "  Rep $i: Ejecución=$ejec s"
            else
                echo "$P,$N,ERROR,ERROR,ERROR" >> $OUTPUT
                echo "  Rep $i: ERROR"
            fi
        done
    done
done

echo ""
echo "Resultados guardados en: $OUTPUT"
echo ""
echo "Promedios por configuración:"
awk -F',' 'NR>1 && $3!="ERROR" {sum[$1","$2]+=$3; count[$1","$2]++} 
     END {for(key in sum) print key": "sum[key]/count[key]" s"}' $OUTPUT | sort
