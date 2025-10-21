#!/bin/bash

# Script para realizar pruebas de rendimiento del algoritmo de ranking
# con diferentes cantidades de procesos y elementos

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
EXECUTABLE="./rank"
OUTPUT_FILE="resultados_benchmark.csv"
LOG_FILE="benchmark.log"

# Arrays de configuración
PROCESSES=(1 4 9 16 25)
ELEMENTS=(10000 30000 50000 80000 100000)
REPETICIONES=5  # Número de repeticiones por cada configuración

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Benchmark de Algoritmo de Ranking  ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Compilar el programa
echo -e "${YELLOW}Compilando el programa...${NC}"
mpicxx -o rank main.cpp -std=c++17
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: La compilación falló${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Compilación exitosa${NC}"
echo ""

# Crear/limpiar archivo de resultados
echo "Procesos,Elementos,Rep,Tiempo_Ejecucion,Tiempo_Computo,Tiempo_Comunicacion" > "$OUTPUT_FILE"

# Función para calcular raíz cuadrada entera sin bc (método de Newton)
sqrt_int() {
    local n=$1
    local x=$n
    local y=$(( (x + 1) / 2 ))
    while [ $y -lt $x ]; do
        x=$y
        y=$(( (x + n / x) / 2 ))
    done
    echo $x
}

# Función para verificar si un número es cuadrado perfecto
es_cuadrado_perfecto() {
    local n=$1
    local sqrt=$(sqrt_int $n)
    local cuadrado=$((sqrt * sqrt))
    [ $cuadrado -eq $n ]
}

# Función para verificar si la configuración excede el límite del buffer
es_configuracion_valida() {
    local procs=$1
    local elementos=$2

    # Caso especial: con 1 proceso no hay comunicación, siempre es válido
    if [ $procs -eq 1 ]; then
        return 0
    fi

    local sqrt_procs=$(sqrt_int $procs)

    # Calcular el tamaño del mensaje por proceso
    local msg_size=$((elementos / procs))

    # Después del gossip, cada proceso acumula datos de sqrt_procs procesos
    # Este es el dato que se envía por MPI y debe caber en el buffer
    local max_data=$((msg_size * sqrt_procs))

    # El buffer en el código es de 10000 caracteres
    # Dejar espacio solo para el terminador null (+1)
    local buffer_limit=9999

    if [ $max_data -gt $buffer_limit ]; then
        return 1  # No válida
    else
        return 0  # Válida
    fi
}

# Función para ejecutar una prueba
ejecutar_prueba() {
    local procs=$1
    local elementos=$2
    local rep=$3

    echo -e "${YELLOW}Ejecutando: P=$procs, N=$elementos, Rep=$rep${NC}"

    # Verificar si la configuración es válida antes de ejecutar
    if ! es_configuracion_valida $procs $elementos; then
        echo -e "${RED}  ⚠ Configuración excede límite de buffer (saltando)${NC}"
        echo "$procs,$elementos,$rep,BUFFER_EXCEEDED,BUFFER_EXCEEDED,BUFFER_EXCEEDED" >> "$OUTPUT_FILE"
        echo "Saltado: P=$procs, N=$elementos, Rep=$rep (excede límite de buffer)" >> "$LOG_FILE"
        return
    fi

    # Ejecutar el programa y capturar stdout y stderr por separado
    output=$(mpiexec -n $procs $EXECUTABLE $elementos 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Extraer los tiempos de la salida
        tiempo_ejecucion=$(echo "$output" | grep "Ejecucion:" | awk '{print $2}')
        tiempo_computo=$(echo "$output" | grep "Computo:" | awk '{print $2}')
        tiempo_comunicacion=$(echo "$output" | grep "Comunicacion:" | awk '{print $2}')

        # Verificar que se obtuvieron los tiempos
        if [ -z "$tiempo_ejecucion" ] || [ -z "$tiempo_computo" ] || [ -z "$tiempo_comunicacion" ]; then
            echo -e "${RED}  ✗ Error: no se pudieron extraer los tiempos${NC}"
            echo "$procs,$elementos,$rep,ERROR,ERROR,ERROR" >> "$OUTPUT_FILE"
            echo "Error extrayendo tiempos para P=$procs, N=$elementos, Rep=$rep:" >> "$LOG_FILE"
            echo "$output" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        else
            # Guardar en el archivo CSV
            echo "$procs,$elementos,$rep,$tiempo_ejecucion,$tiempo_computo,$tiempo_comunicacion" >> "$OUTPUT_FILE"
            echo -e "${GREEN}  ✓ Ejecución: ${tiempo_ejecucion}s | Cómputo: ${tiempo_computo}s | Comunicación: ${tiempo_comunicacion}s${NC}"
        fi
    else
        echo -e "${RED}  ✗ Error en la ejecución (código: $exit_code)${NC}"
        echo "$procs,$elementos,$rep,ERROR,ERROR,ERROR" >> "$OUTPUT_FILE"
        echo "Error con P=$procs, N=$elementos, Rep=$rep (exit code: $exit_code):" >> "$LOG_FILE"
        echo "$output" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
}

# Iniciar benchmark
echo -e "${BLUE}Iniciando pruebas...${NC}"
echo ""
echo "" > "$LOG_FILE"

total_pruebas=$((${#PROCESSES[@]} * ${#ELEMENTS[@]} * REPETICIONES))
prueba_actual=0

# Bucle principal de pruebas
for procs in "${PROCESSES[@]}"; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Probando con $procs procesos${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Verificar si el número de procesos es cuadrado perfecto
    if ! es_cuadrado_perfecto $procs; then
        echo -e "${RED}⚠ Saltando P=$procs (no es cuadrado perfecto)${NC}"
        for elementos in "${ELEMENTS[@]}"; do
            for rep in $(seq 1 $REPETICIONES); do
                echo "$procs,$elementos,$rep,SKIP,SKIP,SKIP" >> "$OUTPUT_FILE"
            done
        done
        echo ""
        continue
    fi
    
    for elementos in "${ELEMENTS[@]}"; do
        for rep in $(seq 1 $REPETICIONES); do
            prueba_actual=$((prueba_actual + 1))
            progreso=$((prueba_actual * 100 / total_pruebas))
            echo -e "${BLUE}[Progreso: $progreso%] ($prueba_actual/$total_pruebas)${NC}"
            
            ejecutar_prueba $procs $elementos $rep
            
            # Pequeña pausa entre ejecuciones
            sleep 0.5
        done
        echo ""
    done
    echo ""
done

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  ✓ Benchmark completado${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Resultados guardados en: ${YELLOW}$OUTPUT_FILE${NC}"
echo -e "Log de errores en: ${YELLOW}$LOG_FILE${NC}"
echo ""

# Generar resumen estadístico
echo -e "${BLUE}Generando resumen estadístico...${NC}"

# Crear script Python para análisis (opcional)
cat > analizar_resultados.py << 'EOF'
#!/usr/bin/env python3
import pandas as pd
import sys

try:
    # Leer el archivo CSV
    df = pd.read_csv('resultados_benchmark.csv')

    # Filtrar errores, skips y configuraciones que exceden buffer
    df = df[(df['Tiempo_Ejecucion'] != 'ERROR') &
            (df['Tiempo_Ejecucion'] != 'SKIP') &
            (df['Tiempo_Ejecucion'] != 'BUFFER_EXCEEDED')]
    
    # Convertir a numérico
    df['Tiempo_Ejecucion'] = pd.to_numeric(df['Tiempo_Ejecucion'])
    df['Tiempo_Computo'] = pd.to_numeric(df['Tiempo_Computo'])
    df['Tiempo_Comunicacion'] = pd.to_numeric(df['Tiempo_Comunicacion'])
    
    # Calcular estadísticas por configuración
    stats = df.groupby(['Procesos', 'Elementos']).agg({
        'Tiempo_Ejecucion': ['mean', 'std', 'min', 'max'],
        'Tiempo_Computo': ['mean', 'std'],
        'Tiempo_Comunicacion': ['mean', 'std']
    }).round(6)
    
    print("\n" + "="*80)
    print("RESUMEN ESTADÍSTICO DE RESULTADOS")
    print("="*80)
    print(stats)
    
    # Guardar tabla resumida
    stats.to_csv('resumen_estadistico.csv')
    print("\n✓ Resumen guardado en: resumen_estadistico.csv")
    
    # Crear tabla pivote para visualización
    pivot = df.groupby(['Procesos', 'Elementos'])['Tiempo_Ejecucion'].mean().unstack()
    print("\n" + "="*80)
    print("TABLA DE TIEMPOS PROMEDIO (Ejecución en segundos)")
    print("="*80)
    print(pivot.round(6))
    pivot.to_csv('tabla_tiempos.csv')
    print("\n✓ Tabla guardada en: tabla_tiempos.csv")
    
except Exception as e:
    print(f"Error al procesar resultados: {e}", file=sys.stderr)
    sys.exit(1)
EOF

chmod +x analizar_resultados.py

# Ejecutar análisis si Python está disponible
if command -v python3 &> /dev/null; then
    echo ""
    python3 analizar_resultados.py
else
    echo -e "${YELLOW}Python3 no encontrado. Saltando análisis estadístico.${NC}"
    echo -e "${YELLOW}Instala Python3 y pandas para ver el análisis automático.${NC}"
fi

echo ""
echo -e "${GREEN}¡Proceso completado!${NC}"
