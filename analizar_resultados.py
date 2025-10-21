#!/usr/bin/env python3
import pandas as pd
import sys

try:
    # Leer el archivo CSV
    df = pd.read_csv('resultados_benchmark.csv')
    
    # Filtrar errores y skips
    df = df[(df['Tiempo_Ejecucion'] != 'ERROR') & 
            (df['Tiempo_Ejecucion'] != 'SKIP')]
    
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
