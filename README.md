# 🏙️ Urban Mobility Intelligence System - Bangalore

> **End-to-end fleet intelligence platform** built for urban mobility operators.  
> Detects dead zones, predicts demand spikes, optimizes fleet repositioning,  
> and delivers EV charging intelligence - on 500,000 real-simulated Bangalore rides.

![Python](https://img.shields.io/badge/Python-3.10+-blue?style=flat-square&logo=python)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-336791?style=flat-square&logo=postgresql)
![XGBoost](https://img.shields.io/badge/XGBoost-2.0.3-orange?style=flat-square)
![SHAP](https://img.shields.io/badge/SHAP-Explainability-green?style=flat-square)
![Power BI](https://img.shields.io/badge/PowerBI-Dashboard-yellow?style=flat-square&logo=powerbi)
![Streamlit](https://img.shields.io/badge/Streamlit-Live_App-red?style=flat-square&logo=streamlit)
![H3](https://img.shields.io/badge/Uber_H3-Spatial_Indexing-purple?style=flat-square)

---

## 🎯 The Business Problem

Mobility companies like Rapido, BluSmart, and Yulu lose **35-50% of fleet value daily** to idle vehicles. Vehicles sit in low-demand residential zones while high-demand tech parks and transit hubs face 18-minute wait times. Operations teams fix this with WhatsApp messages and gut feel.

This system replaces that with a data engine.

---

## 🏗️ System Architecture

Raw Data (6 datasets, 511K rows)
↓
PostgreSQL 17 (6 tables, 12 indexes)
↓
SQL Analytical Layer (12 business queries)
↓
┌─────────────────────────────────────┐
│  Spatial Engine   │  ML Engine      │
│  H3 Hexagonal     │  XGBoost +      │
│  Zone Mapping     │  SHAP           │
├─────────────────────────────────────┤
│  Forecasting      │  EV Optimizer   │
│  Gradient         │  Charging       │
│  Boosting         │  Windows        │
└─────────────────────────────────────┘
↓
┌──────────────────────────────────┐
│  Power BI    │  Streamlit  │  Excel  │
│  Dashboard   │  Live App   │  Report │
└──────────────────────────────────┘

---

## 📊 Dataset Overview

| Dataset | Rows | Description |
|---|---|---|
| `rides.csv` | 500,000 | Every ride - zone, time, fare, weather, event, surge |
| `zones.csv` | 200 | Bangalore zones with H3 indexes, demand weights |
| `drivers.csv` | 2,000 | Driver profiles - EV/petrol, ratings, shifts, earnings |
| `weather.csv` | 8,784 | Hourly Bangalore weather - monsoon-accurate, 2024 |
| `events.csv` | 132 | IPL, concerts, bandhs, festivals with demand multipliers |
| `charging_stations.csv` | 85 | EV stations - 8 networks, 3 charger types |

**City:** Bangalore, Karnataka  
**Period:** January - November 2024  
**Company Simulated:** Rapido

---

## 🔍 Key Business Insights Discovered

### Dead Zone Intelligence
- **20 Critical Dead Zones** identified - Jayanagar 4B, JP Nagar Phase 2, Sadashivanagar with 11-13 idle drivers during peak hours
- **6 Critical Demand Gap zones** - Old Airport Road at 779 rides/driver with 6% unmet demand
- **₹32,991 daily revenue gain** possible by repositioning 39 drivers from surplus to deficit zones

### Demand Intelligence
- **Peak hour:** 18:00 on weekdays - ₹4.64 lakh in revenue lost to unmet demand every hour
- **Heavy rain** increases demand by up to **2.1x** - fare lifts from ₹299 (clear) to ₹556 (heavy rain)
- **New Year Eve** highest demand multiplier at 2.50x - 1.2 lakh expected attendees

### Driver Earnings Equity
- **Wilson Garden** drivers earn **37.2% below city average** - ₹2.41 lakh monthly shortfall
- **21 Critical Underpaid Zones** - all residential, all flagged as critical retention risk
- **Devanahalli and Aerospace Park** drivers earn 70-130% above average

### EV & Charging
- **₹7.33 Cr monthly charging revenue** across 85 stations, 8 networks
- **ChargeZone** leads utilization at 63% - highest efficiency network
- **Rapido Internal** lowest at 45% - internal fleet charging underutilized
- **Ultra Fast DC** generates highest revenue per station at ₹44M monthly

---

## 🤖 ML Model Performance

**Model:** XGBoost Classifier - Demand Spike Prediction  
**Target:** Predict if a zone-hour will experience a demand spike (top 25% rides)

| Metric | Score |
|---|---|
| Accuracy | **90.53%** |
| ROC-AUC | **0.9627** |
| Precision | **1.0000** ← Zero false alarms |
| Recall | 0.8474 |
| F1 Score | 0.9174 |
| False Positives | **0** |

**SHAP Top Features:**
1. Zone Demand Weight - 3.4084
2. Avg Wait Time - 0.6165
3. Zone Type - 0.5644
4. Completion Rate - 0.5600
5. Evening Peak Hour - 0.0701

**Scenario Test:**  
Koramangala 1B | Friday 6pm | Heavy Rain → **Spike Probability: 99.6%** ⚡

---

## 📈 Demand Forecast Performance

**Model:** Gradient Boosting Regressor  
**Accuracy:** 94.1% (MAPE: 5.9%)  
**MAE:** 100.6 rides/day  
**Forecast Period:** 60 days ahead  
**Peak Predicted:** December 29, 2024 - 2,372 rides (Sunburn Festival)

---

## 🗺️ Spatial Intelligence - H3 Hexagonal Mapping

Built using **Uber's H3 hexagonal indexing library** at Resolution 8 (~500m cells).

4 interactive maps produced:
- `01_dead_zone_intelligence_map.html` - Zone classification choropleth
- `02_demand_heatmap.html` - All-hours vs peak-hours demand heatmap
- `03_ev_charging_intelligence_map.html` - 85 charging stations by network
- `04_repositioning_recommendation_map.html` - Driver movement arrows

H3 hexagonal indexing is used internally at Uber for surge pricing.  
Every cell is equidistant from its 6 neighbors - geometrically accurate demand modeling.

---

## 🛠️ Tech Stack

| Layer | Tools |
|---|---|
| Language | Python 3.10 |
| Data Processing | pandas, numpy |
| Spatial Intelligence | H3 (Uber), GeoPandas, Folium |
| ML & Explainability | XGBoost, SHAP, scikit-learn |
| Forecasting | Gradient Boosting, statsmodels |
| Database | PostgreSQL 17, SQLAlchemy, psycopg2 |
| Visualization | Plotly, Power BI |
| Web App | Streamlit, streamlit-folium |
| Reporting | openpyxl (Excel) |
| Version Control | Git, GitHub |

---

## 📁 Project Structure

urban-mobility-intelligence-bangalore/
│
├── data/
│   ├── raw/                    # 6 generated datasets
│   ├── processed/              # Cleaned + enriched outputs
│
├── notebooks/
│   ├── 01_data_generation.ipynb
│   ├── 02_database_loading.ipynb
│   ├── 03_spatial_engine.ipynb
│   ├── 04_forecasting.ipynb
│   ├── 05_ml_model.ipynb
│   └── 06_excel_export.ipynb
│
├── sql/
│   ├── 01_schema_create.sql
│   ├── 02_dead_zone_analysis.sql
│   ├── 03_demand_supply_gap.sql
│   ├── 04_driver_earnings_equity.sql
│   ├── 05_peak_hour_analysis.sql
│   ├── 06_zone_efficiency_score.sql
│   ├── 07_event_impact_analysis.sql
│   ├── 08_weather_impact_analysis.sql
│   ├── 09_repositioning_recommendations.sql
│   ├── 10_ev_charging_windows.sql
│   ├── 11_cohort_zone_performance.sql
│   └── 12_executive_summary_view.sql
│
├── outputs/
│   ├── maps/                   # 4 interactive HTML maps
│   ├── charts/                 # 10 Plotly charts
│   └── excel/                  # Executive Excel report
│
├── dashboard/
│   └── RapidoIQ_Fleet_Intelligence_Dashboard.pbix
│
├── app/
│   └── streamlit_app.py
│
├── requirements.txt
└── README.md

---

## 🚀 Running This Project Locally

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/urban-mobility-intelligence-bangalore.git
cd urban-mobility-intelligence-bangalore
```

### 2. Create virtual environment
```bash
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Mac/Linux
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Set up PostgreSQL
```bash
# Create database
psql -U postgres -c "CREATE DATABASE urban_mobility_db;"

# Run schema
psql -U postgres -d urban_mobility_db -f sql/01_schema_create.sql
```

### 5. Generate data and load database
```bash
# Run notebooks in order
jupyter notebook notebooks/01_data_generation.ipynb
jupyter notebook notebooks/02_database_loading.ipynb
```

### 6. Run the Streamlit app
```bash
streamlit run app/streamlit_app.py
```

---

## 📋 SQL Analytical Layer - 12 Business Queries

| Query | Business Question Answered |
|---|---|
| 01 Schema | Database architecture - 6 tables, 12 indexes |
| 02 Dead Zone Detection | Which zones have idle drivers during peak hours? |
| 03 Demand Supply Gap | Which hours have worst mismatch between supply and demand? |
| 04 Driver Earnings Equity | Which zones structurally underpay drivers? |
| 05 Peak Hour Analysis | Which zones perform best and worst during peak hours? |
| 06 Zone Efficiency Score | Composite zone health score across all KPIs |
| 07 Event Impact Analysis | How much does each event type lift demand and revenue? |
| 08 Weather Impact Analysis | How does rain and temperature affect ride volume and fares? |
| 09 Repositioning Recommendations | Where should drivers move right now? |
| 10 EV Charging Windows | When should EV drivers charge without disrupting service? |
| 11 Cohort Zone Performance | Which zones are improving vs declining month-over-month? |
| 12 Executive Summary View | Single-view C-suite intelligence snapshot |

---

## 📊 Power BI Dashboard - RapidoIQ

![Executive Command Center](https://github.com/MohsinR11/urban-mobility-intelligence-bangalore/blob/main/Dashboard/Screenshots/Page%201%20Executive%20Command%20Center.png)

5-page executive dashboard built on live PostgreSQL connection:

| Page | Focus |
|---|---|
| Executive Command Center | KPIs, revenue, hourly demand, ride status |
| Dead Zone Intelligence | Zone classification, unmet demand, top zones |
| Demand & Revenue Analytics | Weather impact, event analysis, surge patterns |
| Driver Intelligence | Earnings equity, fleet composition, shift analysis |
| EV & Charging Network | Network performance, utilization, charger types |

---

## 💼 Business Impact Summary

> *"This system would reduce daily fleet idle cost by ₹32,991 at minimum through data-driven repositioning - replacing WhatsApp-based operations decisions with a predictive intelligence engine that a Rapido operations head can act on every morning."*

| Business Problem | This System's Solution | Quantified Impact |
|---|---|---|
| Idle fleet waste | Dead zone detection + repositioning map | ₹32,991/day recoverable |
| Missed demand | Demand gap analysis + spike prediction | 25,132 unmet rides identified |
| Driver attrition | Earnings equity analysis | 21 critical underpaid zones flagged |
| Reactive surge pricing | 60-day demand forecast + event calendar | 94.1% forecast accuracy |
| EV charging disruption | Optimal charging window model | ₹7.33 Cr monthly EV revenue tracked |
| No-warning demand spikes | XGBoost spike predictor | 90.5% accuracy, zero false alarms |

---

## 👤 Author

Built for the Indian data analytics job market - targeting roles at mobility companies, fintech, and analytics-first startups.

**Mohsin Raza**

**Open to data analyst opportunities.**  

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/mohsinraza-data/)

---

## ⭐ If this project helped you

Give it a star. It took a whole week to build and helps others understand what a real end-to-end analytics project looks like.
