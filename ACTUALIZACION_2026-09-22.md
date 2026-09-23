# Actualización del repositorio — 2026-09-22

## Fuente revisada

La información se consolidó desde los archivos MQL5 y los resultados existentes en `Files/GitHub/TradeX_QuantORB_MT5/`.

## Cambios reflejados

- Se actualizó el README raíz, que anteriormente solo identificaba el repositorio.
- Se añadieron enlaces directos a los dos EAs, configuraciones y reportes.
- Se documentó la configuración ORB de 16:30–16:45 como configuración recomendada.
- Se incorporaron las métricas históricas 2023, 2024, 2025 y 2026 YTD.
- Se documentaron correcciones de lotaje, SL mínimo, margen, trailing y reintentos.
- Se dejó explícita la diferencia entre resultados brutos y netos de comisiones.

## Integridad y seguridad

- No se modificaron los archivos MQL5 fuente ni los resultados existentes.
- No se incluyeron credenciales, `.env` ni datos de cuentas.
- El binario local `.ex5` sin seguimiento permanece fuera del commit.

## Validación recomendada

Recompilar en MetaEditor y ejecutar los cuatro `.ini` anuales con `h24_16.set`. Comparar PF, DD equity, beneficio neto y comisiones con los JSON y `comisiones_reales.md`.
