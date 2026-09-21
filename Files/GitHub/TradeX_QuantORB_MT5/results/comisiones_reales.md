# Análisis realista con comisiones del broker (Pepperstone Razor)

Cálculo basado en los **lotes reales de cada operación** extraídos del log del Strategy
Tester (no estimación por promedio). Comisión aplicada: **3.50 USD/lote/lado**
(7.00 USD por lote ida y vuelta), tarifa publicada oficial de Pepperstone Razor y
verificada en operación real demo (deal de 1.14 lotes → 3.99 USD/lado).

## Resultados netos (config 16:30–16:45, EOD OFF, TP 6, MinSL 20, BE 4, margen 50%)

| Año | Profit sin comisión | Lotes totales | Comisión total | **Profit NETO** | % del bruto |
|-----|--------------------|---------------|----------------|-----------------|-------------|
| 2023 | $85,136.87 | 3,928.20 | $27,497.40 | **$57,639.47** | 67.7% |
| 2024 | $120,241.91 | 4,228.09 | $29,596.63 | **$90,645.28** | 75.4% |
| 2025 | $91,290.34 | 1,923.72 | $13,466.04 | **$77,824.30** | 85.2% |
| 2026 (YTD) | $62,300.49 | 1,178.30 | $8,248.10 | **$54,052.39** | 86.8% |

- La estrategia **sigue siendo muy rentable** tras comisiones reales: +54k a +90k $/año.
- Los lotes altos (2023–2024) reflejan la capitalización del balance con SL 20 puntos;
  la comisión crece con el tamaño pero el beneficio neto permanece ampliamente positivo.

## Comparativa de brokers (comisión XAUUSD por lote, ida y vuelta)

| Broker | Cuenta | Comisión redondo/lote | Coste/lado | Notas |
|--------|--------|----------------------|------------|-------|
| **Vantage** | RAW ECN | **$6** | ≈$3.00 | La más barata en metales (publicado oficial) |
| Pepperstone | Razor | $7 | $3.50 | Cuenta actual (demo) |
| IC Markets | Raw Spread | $7 | $3.50 | Mismo estándar |
| Exness | Raw Spread | $7 | $3.50 | Zero: más cara ($5.50/lado) |
| Tickmill | Raw | ~$6-7 | ~$3.00-3.50 | Confiable spread ajustado en oro |

**Potencial de ahorro con Vantage (~$6/lote RT):** comisión total −14%, lo que
elevaría los beneficios netos a ≈ +61,600 (2023), +94,900 (2024), +79,700 (2025),
+55,200 (2026).

## Notas metodológicas

- El Strategy Tester de MT5 **no aplicó comisión** en los backtests (confirmado
  empíricamente: reporte con `Commission=3.5` en el .ini → resultado idéntico).
  Por eso se calculó a partir de los lotes reales del log del tester.
- El **spread ya está incluido** en los backtests: modo "every tick" con datos
  reales Bid/Ask del broker.
- Swap no modelado en el tester; con EOD OFF y TP ratio 6 la mayoría de operaciones
  cierran intraday (casos overnight son raros pero posibles).
- Script: `MQL5/Files/Temp/analyze_comm.py` (lectura del log del tester, UTF-16).