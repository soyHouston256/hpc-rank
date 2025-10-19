# Benchmark de Algoritmo de Ranking MPI

Este directorio contiene scripts para realizar pruebas de rendimiento del algoritmo de ranking paralelo.

## Archivos

- `main.cpp`: Implementación del algoritmo de ranking paralelo con MPI
- `rank.sh`: Script completo de benchmark con análisis estadístico
- `rank_simple.sh`: Script simplificado para pruebas rápidas
- `analizar_resultados.py`: Script Python generado automáticamente para análisis

## Requisitos

- MPI (OpenMPI o MPICH)
- C++ compiler compatible con C++17
- Python3 con pandas (opcional, para análisis estadístico)

## Uso

### Script Completo (rank.sh)

Este script realiza pruebas exhaustivas con múltiples repeticiones:

```bash
./rank.sh
```

**Características:**
- Prueba con 1, 4, 8, 16, 32 procesos (salta los que no son cuadrados perfectos)
- Prueba con 10000, 30000, 50000, 80000, 100000 elementos
- 5 repeticiones por configuración por defecto
- Genera archivos CSV con resultados
- Análisis estadístico automático con Python

**Salidas:**
- `resultados_benchmark.csv`: Resultados detallados de todas las ejecuciones
- `resumen_estadistico.csv`: Estadísticas (media, desviación, min, max)
- `tabla_tiempos.csv`: Tabla pivote de tiempos promedio
- `benchmark.log`: Log de errores

### Script Simplificado (rank_simple.sh)

Para pruebas rápidas:

```bash
./rank_simple.sh [repeticiones]
```

Ejemplo:
```bash
./rank_simple.sh 3    # 3 repeticiones por configuración
```

**Características:**
- Solo prueba con 1, 4, 16 procesos (cuadrados perfectos)
- Todas las configuraciones de elementos
- Muestra promedios al final

**Salida:**
- `resultados_simple.txt`: Resultados en formato CSV simple

## Configuración de Pruebas

| P (Procesos) | N (Elementos) | Válido |
|--------------|---------------|--------|
| 1            | 10000-100000  | ✓      |
| 4            | 10000-100000  | ✓      |
| 8            | 10000-100000  | ✗*     |
| 16           | 10000-100000  | ✓      |
| 32           | 10000-100000  | ✗*     |

*Nota: 8 y 32 no son cuadrados perfectos, el programa los saltará automáticamente.*

## Modificar Configuración

### En rank.sh:

Edita estas líneas:
```bash
PROCESSES=(1 4 8 16 32)           # Números de procesos a probar
ELEMENTS=(10000 30000 50000 80000 100000)  # Tamaños de entrada
REPETICIONES=5                     # Repeticiones por configuración
```

### En rank_simple.sh:

Edita el bucle for:
```bash
for P in 1 4 16; do               # Procesos (solo cuadrados perfectos)
    for N in 10000 30000 50000 80000 100000; do  # Elementos
```

## Interpretar Resultados

Los scripts miden tres tiempos:

1. **Tiempo de Ejecución**: Tiempo total sin incluir el ordenamiento final
2. **Tiempo de Cómputo**: Tiempo de operaciones locales (sort + ranking local)
3. **Tiempo de Comunicación**: Tiempo de operaciones MPI (scatter, gossip, broadcast, reduce, gather)

### Fórmula:
```
Tiempo_Ejecucion = Tiempo_Computo + Tiempo_Comunicacion
```

## Análisis de Escalabilidad

Para analizar la escalabilidad:

```bash
# Speedup = T(1) / T(P)
# Efficiency = Speedup / P

# Ejemplo con Python:
python3 << EOF
import pandas as pd
df = pd.read_csv('tabla_tiempos.csv', index_col=0)
speedup = df.loc[1] / df  # T(1 proceso) / T(P procesos)
efficiency = speedup / speedup.index.to_series()
print("Speedup:\\n", speedup)
print("\\nEfficiency:\\n", efficiency)
EOF
```

## Solución de Problemas

**Error: "Number of processes must be a perfect square"**
- Solo usa 1, 4, 9, 16, 25, 36, ... procesos

**Error de compilación:**
```bash
mpicxx --version  # Verificar que MPI esté instalado
```

**Sin Python/pandas:**
- Los scripts funcionan sin Python
- Solo no se generará el análisis estadístico automático
- Puedes analizar los CSV manualmente con Excel u otra herramienta

## Ejemplo de Salida

```
======================================
  Benchmark de Algoritmo de Ranking  
======================================

✓ Compilación exitosa

Iniciando pruebas...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Probando con 1 procesos
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Progreso: 2%] (1/125)
Ejecutando: P=1, N=10000, Rep=1
  ✓ Ejecución: 0.0234s | Cómputo: 0.0123s | Comunicación: 0.0111s
...
```

scp -r ./rank/. max.ramirez@khipu.utec.edu.pe:~/rank/