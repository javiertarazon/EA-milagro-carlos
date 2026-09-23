# TradeX QuantORB MT5

EA de **Opening Range Breakout para XAUUSD**, desarrollado en MQL5. La documentación completa, fuentes, configuraciones y resultados se encuentran en [`Files/GitHub/TradeX_QuantORB_MT5/`](Files/GitHub/TradeX_QuantORB_MT5/).

## Estado actualizado — 2026-09-22

- Fuente principal: [`TradeX_QuantORB_MT5.mq5`](Files/GitHub/TradeX_QuantORB_MT5/TradeX_QuantORB_MT5.mq5).
- Versión corregida Codex: [`TradeX_QuantORB_MT5_Codex.mq5`](Files/GitHub/TradeX_QuantORB_MT5/TradeX_QuantORB_MT5_Codex.mq5).
- Configuración recomendada validada: [`h24_16.set`](Files/GitHub/TradeX_QuantORB_MT5/configs/h24_16.set).
- Resultados por año: [`results/`](Files/GitHub/TradeX_QuantORB_MT5/results/).
- Comisiones reales y comparación de brokers: [`comisiones_reales.md`](Files/GitHub/TradeX_QuantORB_MT5/results/comisiones_reales.md).

## Parámetros recomendados

La configuración validada usa la ventana ORB `16:30–16:45` en hora del broker, TP ratio 6, SL mínimo 20 puntos, margen máximo 50%, breakeven a 4 y máximo 2 operaciones diarias. El EA trabaja internamente con datos M1 aunque se puede adjuntar a un gráfico M5 o superior.

## Métricas históricas documentadas

| Año | Beneficio bruto | PF | DD equity | Operaciones | Win rate |
|---|---:|---:|---:|---:|---:|
| 2023 | +85.137 USD | 3,40 | 3,18% | 395 | 55,4% |
| 2024 | +120.242 USD | 3,92 | 4,76% | 393 | 57,0% |
| 2025 | +91.290 USD | 7,41 | 1,66% | 399 | 59,1% |
| 2026 YTD | +62.300 USD | 7,71 | 1,44% | 297 | 62,0% |

Los resultados netos después de comisión Pepperstone Razor están documentados en `results/comisiones_reales.md`. Son backtests y no garantizan resultados futuros.

## Correcciones y mejoras documentadas

- Prevención de lotes excesivos cuando la entrada queda pegada al rango ORB mediante SL mínimo y cálculo de margen por contrato.
- Cálculo de lotaje limitado por riesgo y margen disponible.
- Cooldown del trailing para evitar errores `Invalid stops`.
- Reintentos restringidos a errores transitorios del servidor.
- Límite de pérdida diaria y cierre opcional de posiciones.
- Validación multi-año de las ventanas ORB y comparación de costes de broker.

## Verificación

Compilar el EA en MetaEditor y ejecutar Strategy Tester con el `.ini` del año correspondiente, datos **Every tick**, XAUUSD M5, depósito 10.000 USD, apalancamiento 1:100 y los inputs de `h24_16.set`.

## Advertencia

Este repositorio contiene software de trading. Validar siempre en demo, revisar spread, comisión, tick value, margen y ejecución del broker antes de cualquier uso real. No se incluyen credenciales ni datos sensibles.
