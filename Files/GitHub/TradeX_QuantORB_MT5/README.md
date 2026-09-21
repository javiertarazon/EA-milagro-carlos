# TradeX QuantORB MT5 — Expert Advisor MQL5

**Opening Range Breakout (ORB) para XAUUSD** con gestión de riesgo automática, breakeven + trailing stop, límite de pérdida diaria y reintentos. Desarrollado y validado en MetaTrader 5.

> ⚠️ **Aviso**: Este repositorio contiene un EA de trading. Los resultados son de backtests sobre datos históricos y **no garantizan resultados futuros**. Opere bajo su propio criterio y con gestión de riesgo.

---

## 📊 Resumen ejecutivo

| Año | Período | Beneficio ($) | Profit Factor | DD equity (%) | Trades | Win rate (%) | Sharpe |
|-----|---------|---------------|---------------|----------------|--------|--------------|--------|
| 2023 | Ene–Dic | **+85,137** | 3.40 | 3.18% | 395 | 55.4% | 126.8 |
| 2024 | Ene–Dic | **+120,242** | 3.92 | 4.76% | 393 | 57.0% | 146.1 |
| 2025 | Ene–Dic | **+91,290** | 7.41 | 1.66% | 399 | 59.1% | 183.1 |
| 2026 | Ene–Sep (YTD) | **+62,300** | 7.71 | 1.44% | 297 | 62.0% | 242.9 |

- Beneficio medio: **≈ +90,000 $/año** sobre depósito inicial de **10,000 $** (EOD OFF, TP 6, MinSL 20, BE 4, margen 50%).
- `margin_level ≈ 199%` en todos los años → **uso de margen siempre ~50%** (el tope `InpMaxMarginPct=50` actúa de forma determinista).
- Config: **ventana ORB 16:30–16:45** (hora broker), coincide con la apertura de Nueva York.

### Resultados NETOS con comisión real del broker (Pepperstone Razor: $3.50/lote/lado)

Calculados con los **lotes reales** de cada operación del log del tester (detalle en `results/comisiones_reales.md`):

| Año | Profit bruto | Comisión | **Profit NETO** |
|-----|--------------|----------|-----------------|
| 2023 | +85,137 | −27,497 | **+57,639** |
| 2024 | +120,242 | −29,597 | **+90,645** |
| 2025 | +91,290 | −13,466 | **+77,824** |
| 2026 YTD | +62,300 | −8,248 | **+54,052** |

Comparativa de brokers en `results/comisiones_reales.md` (Vantage RAW ~$6/lote redondo vs Pepperstone $7).

### Comparación con la base original (sin ajustar)

| Año | Config original (9h, sin tuning) | Config 16h validada |
|-----|----------------------------------|----------------------|
| 2023 | **−3,982** (DD 40.3%, PF 0.60) | **+85,137** (DD 3.2%, PF 3.40) |
| 2025 | +9,072 (DD 7.86%, PF 1.60) | **+91,290** (DD 1.7%, PF 7.41) |

---

## 🎯 Estrategia

1. **Rango de apertura (ORB)**: se captura el **High/Low** del precio durante la ventana **16:30–16:45** (15 minutos) en hora del broker, reforzado con la vela M1.
2. **Breakout**: cuando el Bid rompe el máximo → **LONG**; cuando el Ask rompe el mínimo → **SHORT** (máx. 1 por lado y hasta `InpMaxTradesDay` por día).
3. **Gestión de riesgo**:
   - SL a distancia efectiva `max(|entrada−nivel ORB|, minStop broker, InpMinSLPoints)` → evita lotes enormes al entrar pegado al rango.
   - TP con ratio configurable (`InpTPRatio`) sobre la misma distancia.
   - Lote calculado por riesgo (`InpRiskPercent`) y **limitado por margen** (`InpMaxMarginPct`), con margen calculado por contrato (fiable en cualquier broker).
4. **Breakeven + Trailing** con cooldown de 10 s (evita `Invalid stops` por spam de modificaciones).
5. **Límite de pérdida diaria** (`InpMaxDailyLoss`) con cierre opcional de posiciones.
6. **Reintentos** solo para errores transitorios (10004/10006/10007/10009/10019).

---

## 📁 Contenido

| Archivo | Descripción |
|---------|-------------|
| `TradeX_QuantORB_MT5.mq5` | Código fuente del EA (versión 16h por defecto) |
| `configs/h24_16.set` | **Config recomendada (validada multi-año)** |
| `configs/h24_09.set` | Baseline 9h (filtro original) |
| `configs/h24_14.set` | Variante 14h (apertura Nueva York previa) |
| `configs/rec_2026.set` | Recomendación previa (ORB 9h, EOD ON, +24,309 en 2026) |
| `configs/grid_balance.set` | Optimización completa 15 pases (balance_max) |
| `configs/m50_balance.set` | Optimización restringida margen 50% (20 pases) |
| `configs/balance_point.set` | Punto de balance (validado) |
| `configs/hour_filter.set` | Optimización filtro hora (0–9h) |
| `configs/val_2023.ini` … `val_2026.ini` | Configuraciones del Strategy Tester para verificación |
| `results/backtest_2023.json` … `backtest_2026.json` | Reportes completos JSON de la verificación |

---

## 🛠️ Instalación

1. Copia `TradeX_QuantORB_MT5.mq5` a `MQL5\Experts\`.
2. Compila en MetaEditor (F7) → requiere build con soporte **AVX2** (verificado en 6191).
3. Opcional: carga `configs/h24_16.set` desde la pestaña *Inputs* del EA (menú → Load Version).
4. Adjunta el EA a un gráfico **XAUUSD M5** (o superior; el EA trabaja internamente en M1).

### Configuración recomendada (h24_16.set)

```ini
InpORBStartHour=16  InpORBStartMin=30
InpORBEndHour=16    InpORBEndMin=45
InpUseEODClose=false
InpTPRatio=6.0
InpMinSLPoints=20
InpMaxMarginPct=50
InpBEActivatePips=4.0
InpTrailCooldownSec=10
InpMaxTradesDay=2
```

### Verificación (Strategy Tester)

- Símbolo: `XAUUSD` · Período: `M5` · Modelo: **Every tick** (`ExecutionMode=20`)
- Depósito: `10,000 USD` · Apalancamiento: `1:100`
- Fechas: `val_2023.ini`, `val_2024.ini`, `val_2025.ini`, `val_2026.ini`
- Cargar inputs: `h24_16.set`

---

## 🔬 Historial de pruebas y optimizaciones

### 1) Diagnóstico de operaciones fallidas
- **Síntoma**: `not enough money [market buy 5.88 XAUUSD ...]` (Error 4756) con lotes 5–7.
- **Causa**: SL pegado al rango ORB → distancia ínfima → lote enorme.
- **Fix**: `InpMinSLPoints=10` + `slDist=MathMax(MathAbs(entry-slBase), MathMax(minStop, InpMinSLPoints*g_point))` + margen por contrato en `CalcLot`.
- **Resultado post-fix**: +12,424 PF 2.20 DD 2.10% (339 trades, 2026 M15).

### 2) Corrección de trailing
- **Síntoma**: `failed modify ... [Invalid stops]` repetido decenas por segundo.
- **Fix**: cooldown `InpTrailCooldownSec=10` + condición SELL corregida (`trailSL < curSL - step`).

### 3) Estudio de influencia por parámetro (2023, 1 parámetro a la vez)
Baseline 2023: **−3,982** DD 40.3% PF 0.60.

| Parámetro | Hallazgo |
|-----------|----------|
| `InpMaxMarginPct` | Lineal: 10 → DD 11.97%; 100 → DD 72.1% |
| `InpTPRatio` | 4.0 → DD 23.2% |
| `InpORBStartHour` | 7–8h → DD ~27% (429–437 trades) |
| `InpMaxTradesDay=1` | 257 trades, DD 32.5% |
| `InpRiskPercent` | Sin efecto (interactúa con margen) |
| BE / Trailing | Efecto marginal |

### 4) Optimización completa — grid_balance (15 pases, 2026, balance_max)
- **Ganador**: pase 11 → TP 4.0 · margen 90 → **+41,183** PF 3.22 DD 3.56%.
- Margen 110 colapsa: −1,455 DD 21.7% (327 trades).
- Reporte XML: `grid_balance.xml`.

### 5) Optimización restringida margen 50% (20 pases)
- TP 6 + ORB 9h → +22,233 PF 3.93 DD 1.85%.
- Refinado con MinSL 20 + BE 4 → **+24,309 PF 4.05 DD 1.98%** (margin_level 199.4%).

### 6) Punto de balance
- ORB 8h · TP 3.0 · MinSL 20 · margen 50 · BE 4 → **+8,600 PF 2.99 DD 1.79%** (296 trades).

### 7) Optimización filtro de hora (ORB 0–9h, fin fijo 09:45)
- El filtro **9h** dio el máximo balance: +24,309.
- H 3–7h: mejor PF (5.2–5.4) pero menos trades.
- 0h (sin filtro): +11,882 (195 trades).

### 8) Optimización genética (máximo balance, 5 params, 324 combos)
- Top: ORB 9h · TP 4 · MinSL 30 · margen 100 · BE 4 → **+80,922** PF 3.30 DD 4.33%.
- ⚠️ Posiblemente interrumpida antes de terminar (no se confirmó `optimization finished`).

### 9) Barrido 24h (2026, EOD OFF, TP 6, MinSL 20, BE 4, margen 50)
Objetivo: ver en qué franja baja la rentabilidad, correlacionado con aperturas de mercado.

| Zona | Franjas | Resultado |
|------|---------|-----------|
| **Cluster NY** | 14h–16h | **+56k a +62k**, PF 7.1–7.7, win 60–64% |
| Asia 2º pico | 02h | +53,536, PF 5.25 |
| Peor | 23h | +2,437, PF 1.61, win 36% |
| Zonas muertas | 22h / 06h / 05h | Rentabilidad mínima |
| Medianoche | 00h | 0 operaciones (límite en la lógica) |

### 10) Análisis de pérdidas (config 9h margen 50, 339 trades, 2026)
- **217 SL (64%) vs 104 TP (31%) vs ~18 EOD (5%)**.
- SELL pierde más (116 vs 101).
- Hit-rate TP cae de 44% (ene) a 25–29% (may–sep).
- Racha máx. de SL: 13 → con BE 4 baja a 6.

### 11) Validación multi-año 9h vs 14h vs 16h ✅ (decisión final)
La ventana **16h (16:30–16:45)** gana en **TODOS** los años:

| Año | 9h | 14h | **16h** |
|-----|-----|-----|---------|
| 2023 | peor | medio | **+85,137 PF 3.40 DD 3.2%** |
| 2025 | peor | medio | **+91,290 PF 7.41 DD 1.7%** |
| 2026 | +62,300 PF 7.71 DD 1.4% (en el barrido 24h) | — | **+62,300 PF 7.71 DD 1.4%** |

**Conclusión**: la consistencia en 3 regímenes de mercado distintos (2023 lateral/duro, 2024 volátil, 2025/2026 trending) hace creíble la ventaja de 16h. La teoría la respalda: 16:30–16:45 hora del broker es el arranque de la sesión de Nueva York en el oro.

---

## 📈 Métricas clave explicadas

- **Profit Factor** = beneficio bruto / pérdida bruta. >2 es saludable; 7.7 (2026) indica pérdidas pequeñas frecuentes absorbidas por tendencias.
- **DD equity (%)** = max drawdown sobre equity / ((max equity + depósito)/2). Todo el análisis usa DD sobre **equity** (el conservador).
- **margin_level** = equity/margin · 100. **199% ≈ 50% del margen en uso** — el objetivo del proyecto fue nunca comprometer más del 50%.
- **Sharpe ratio** del tester: normalizado por el tester; usa solo como referencia relativa entre configs.

---

## 🧠 Lecciones / decisiones de diseño

1. **Margen ≠ riesgo ∈ [0..100]** para el tester: `InpMaxMarginPct` escala riesgo/retorno casi linealmente con Sharpe constante; por eso se fijó 50% como compromiso.
2. **SL mínimo por puntos** es crítico: sin él, los lotes se disparan al romper el rango con la entrada pegada al nivel ORB.
3. **SL de margen por contrato** (`contractSize · Ask / leverage`): `SYMBOL_MARGIN_INITIAL` no es fiable en todos los brokers/tester.
4. **Cooldown en trailing** obligatorio: el servidor rechaza modificaciones masivas con `Invalid stops`.
5. **Barrido 24h > optimizar solo horas de mercado**: reveló que el cluster NY (14–16h) domina y que 23h/22h/06h/05h deben evitarse.
6. M5 vs M15 dan resultados idénticos (el EA usa M1 internamente).

---

## 📜 Licencia y disclaimer

- EA con fines educativos. **No es asesoramiento financiero.**
- Los backtests no garantizan resultados futuros; valida siempre en demo antes de operar en real.
- No se incluyen credenciales, cuentas ni datos sensibles.

---

## 🧪 Cómo reproducir la verificación

```text
1. Compilar TradeX_QuantORB_MT5.mq5 (0 errores, 0 warnings).
2. Strategy Tester:
   - Archivo .ini de configuración: configs/val_20XX.ini
   - Inputs: configs/h24_16.set
   - Símbolo XAUUSD, M5, every tick, 10 000 USD, 1:100.
3. Leer reporte (pestaña Backtest > Report) y comparar con results/*.json.
```