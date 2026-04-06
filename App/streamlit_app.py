# ============================================================
# RAPIDOIQ — FLEET INTELLIGENCE COMMAND CENTER
# Streamlit Live Web Application
# Urban Mobility Dead Zone & Demand Gap Intelligence System
# City: Bangalore | Company: Rapido
# ============================================================

import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import folium
from streamlit_folium import st_folium
import h3
import os
import warnings
warnings.filterwarnings('ignore')

# ── Page Configuration ───────────────────────────────────────
st.set_page_config(
    page_title = "RapidoIQ - Fleet Intelligence",
    page_icon  = "🏙️",
    layout     = "wide",
    initial_sidebar_state = "expanded",
)

# ── Custom CSS ───────────────────────────────────────────────
st.markdown("""
<style>
    /* Main background */
    .stApp {
        background-color: #1a1a2e;
        color: #ffffff;
    }
    /* Sidebar */
    [data-testid="stSidebar"] {
        background-color: #16213e;
        border-right: 1px solid #0f3460;
    }
    /* Metric cards */
    [data-testid="stMetric"] {
        background-color: #16213e;
        border: 1px solid #0f3460;
        border-radius: 8px;
        padding: 12px;
    }
    [data-testid="stMetricLabel"] {
        color: #90caf9 !important;
        font-size: 12px !important;
    }
    [data-testid="stMetricValue"] {
        color: #ffffff !important;
        font-size: 24px !important;
        font-weight: bold !important;
    }
    /* Headers */
    h1, h2, h3 {
        color: #ffffff !important;
    }
    /* Divider */
    hr {
        border-color: #0f3460;
    }
    /* Selectbox */
    .stSelectbox > div > div {
        background-color: #16213e;
        color: #ffffff;
        border-color: #0f3460;
    }
    /* Tab styling */
    .stTabs [data-baseweb="tab-list"] {
        background-color: #16213e;
        border-radius: 8px;
    }
    .stTabs [data-baseweb="tab"] {
        color: #90caf9;
        background-color: #16213e;
    }
    .stTabs [aria-selected="true"] {
        background-color: #e94560 !important;
        color: #ffffff !important;
        border-radius: 6px;
    }
    /* Title banner */
    .title-banner {
        background: linear-gradient(135deg, #e94560, #0f3460);
        padding: 20px 30px;
        border-radius: 12px;
        margin-bottom: 20px;
        text-align: center;
    }
    .title-banner h1 {
        font-size: 28px;
        font-weight: bold;
        margin: 0;
        color: #ffffff !important;
    }
    .title-banner p {
        font-size: 14px;
        color: #90caf9;
        margin: 6px 0 0 0;
    }
    /* KPI card */
    .kpi-card {
        background-color: #16213e;
        border: 1px solid #0f3460;
        border-radius: 10px;
        padding: 16px;
        text-align: center;
        margin: 4px;
    }
    .kpi-value {
        font-size: 28px;
        font-weight: bold;
        color: #ffffff;
    }
    .kpi-label {
        font-size: 11px;
        color: #90caf9;
        margin-top: 4px;
    }
    /* Alert boxes */
    .alert-red {
        background-color: #7f0000;
        border-left: 4px solid #e94560;
        padding: 10px 14px;
        border-radius: 6px;
        margin: 6px 0;
        font-size: 13px;
    }
    .alert-orange {
        background-color: #3e2000;
        border-left: 4px solid #f57c00;
        padding: 10px 14px;
        border-radius: 6px;
        margin: 6px 0;
        font-size: 13px;
    }
    .alert-green {
        background-color: #1b3a1f;
        border-left: 4px solid #2e7d32;
        padding: 10px 14px;
        border-radius: 6px;
        margin: 6px 0;
        font-size: 13px;
    }
</style>
""", unsafe_allow_html=True)

# ── Data Loading ─────────────────────────────────────────────
@st.cache_data
def load_data():
    base = os.path.dirname(os.path.abspath(__file__))
    raw  = os.path.join(base, "..", "data", "raw")
    proc = os.path.join(base, "..", "data", "processed")

    rides_df    = pd.read_csv(os.path.join(raw,  "rides.csv"))
    zones_df    = pd.read_csv(os.path.join(raw,  "zones.csv"))
    drivers_df  = pd.read_csv(os.path.join(raw,  "drivers.csv"))
    stations_df = pd.read_csv(os.path.join(raw,  "charging_stations.csv"))
    events_df   = pd.read_csv(os.path.join(raw,  "events.csv"))
    zone_map    = pd.read_csv(os.path.join(proc, "zone_map_data.csv"))
    forecast_df = pd.read_csv(os.path.join(proc, "citywide_demand_forecast.csv"))

    rides_df['date']      = pd.to_datetime(rides_df['date'])
    forecast_df['date']   = pd.to_datetime(forecast_df['date'])

    return (rides_df, zones_df, drivers_df,
            stations_df, events_df, zone_map, forecast_df)

# Load data
with st.spinner("Loading Fleet Intelligence System..."):
    (rides_df, zones_df, drivers_df,
     stations_df, events_df, zone_map, forecast_df) = load_data()

# ── Precompute key metrics ────────────────────────────────────
completed      = rides_df[rides_df['status'] == 'completed']
total_revenue  = completed['fare_amount'].sum()
comp_rate      = len(completed) / len(rides_df) * 100
unmet_rate     = (rides_df['status'] == 'no_driver_found').mean() * 100
avg_fare       = completed['fare_amount'].mean()
avg_wait       = rides_df['wait_time_min'].mean()
ev_share       = rides_df['vehicle_type'].str.contains('EV').mean() * 100
surge_rate     = (rides_df['surge_multiplier'] > 1.0).mean() * 100
active_drivers = (drivers_df['status'] == 'active').sum()

ZONE_COLORS = {
    'CRITICAL DEAD ZONE'   : '#d32f2f',
    'HIGH IDLE ZONE'       : '#f57c00',
    'CRITICAL DEMAND GAP'  : '#1565c0',
    'HIGH DEMAND GAP'      : '#1976d2',
    'HIGH EFFICIENCY ZONE' : '#2e7d32',
    'BALANCED ZONE'        : '#558b2f',
    'NO DRIVER DATA'       : '#9e9e9e',
}

# ── Sidebar ───────────────────────────────────────────────────
with st.sidebar:
    st.markdown("""
    <div style="text-align:center; padding:10px 0;">
        <div style="font-size:32px;">🏙️</div>
        <div style="font-size:18px; font-weight:bold;
             color:#e94560;">RapidoIQ</div>
        <div style="font-size:11px; color:#90caf9;">
            Fleet Intelligence Command Center
        </div>
        <hr style="border-color:#0f3460; margin:12px 0;">
    </div>
    """, unsafe_allow_html=True)

    st.markdown("**🔍 Global Filters**")

    selected_zone_type = st.selectbox(
        "Zone Type",
        ["All"] + sorted(rides_df['pickup_zone_type'].unique().tolist()),
    )

    selected_vehicle = st.selectbox(
        "Vehicle Type",
        ["All"] + sorted(rides_df['vehicle_type'].unique().tolist()),
    )

    selected_month = st.slider(
        "Month Range",
        min_value = int(rides_df['month'].min()),
        max_value = int(rides_df['month'].max()),
        value     = (int(rides_df['month'].min()),
                     int(rides_df['month'].max())),
    )

    show_weekend = st.radio(
        "Day Type",
        ["All", "Weekday Only", "Weekend Only"],
    )

    st.markdown("<hr style='border-color:#0f3460;'>", unsafe_allow_html=True)
    st.markdown("""
    <div style="font-size:11px; color:#90caf9; text-align:center;">
        <b>Dataset</b><br>
        500,000 rides | 200 zones<br>
        2,000 drivers | 85 EV stations<br>
        132 events | Jan-Nov 2024<br>
        <br>
        <b>City:</b> Bangalore<br>
        <b>Company:</b> Rapido<br>
        <b>Model Accuracy:</b> 90.5%
    </div>
    """, unsafe_allow_html=True)

# ── Apply filters ─────────────────────────────────────────────
filtered = rides_df.copy()

if selected_zone_type != "All":
    filtered = filtered[
        filtered['pickup_zone_type'] == selected_zone_type
    ]
if selected_vehicle != "All":
    filtered = filtered[
        filtered['vehicle_type'] == selected_vehicle
    ]

filtered = filtered[
    (filtered['month'] >= selected_month[0]) &
    (filtered['month'] <= selected_month[1])
]

if show_weekend == "Weekday Only":
    filtered = filtered[filtered['is_weekend'] == False]
elif show_weekend == "Weekend Only":
    filtered = filtered[filtered['is_weekend'] == True]

# ── Title Banner ──────────────────────────────────────────────
st.markdown("""
<div class="title-banner">
    <h1>🏙️ RapidoIQ - Fleet Intelligence Command Center</h1>
    <p>
        Bangalore Urban Mobility | Dead Zone Detection |
        Demand Forecasting | XGBoost Spike Prediction |
        EV Fleet Intelligence
    </p>
</div>
""", unsafe_allow_html=True)

# ── Tabs ──────────────────────────────────────────────────────
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📊 Executive Overview",
    "🗺️ Zone Intelligence Map",
    "📈 Demand & Forecasting",
    "🚗 Driver Intelligence",
    "⚡ EV & Charging",
])

# ============================================================
# TAB 1 — EXECUTIVE OVERVIEW
# ============================================================
with tab1:

    # KPI Row
    k1,k2,k3,k4,k5,k6 = st.columns(6)

    f_completed = filtered[filtered['status']=='completed']
    f_rev  = f_completed['fare_amount'].sum()
    f_comp = len(f_completed)/len(filtered)*100 if len(filtered)>0 else 0
    f_unmet= (filtered['status']=='no_driver_found').mean()*100
    f_fare = f_completed['fare_amount'].mean() if len(f_completed)>0 else 0
    f_wait = filtered['wait_time_min'].mean()

    k1.metric("Total Rides",       f"{len(filtered):,}")
    k2.metric("Total Revenue",     f"₹{f_rev/1e7:.2f}Cr")
    k3.metric("Completion Rate",   f"{f_comp:.1f}%")
    k4.metric("Unmet Demand",      f"{f_unmet:.1f}%")
    k5.metric("Avg Fare",          f"₹{f_fare:.0f}")
    k6.metric("Avg Wait",          f"{f_wait:.1f} min")

    st.markdown("---")

    col1, col2 = st.columns([3, 2])

    with col1:
        # Hourly demand chart
        hourly = filtered.groupby(
            ['hour','is_weekend']
        ).size().reset_index(name='rides')
        hourly['day_type'] = hourly['is_weekend'].map(
            {True:'Weekend', False:'Weekday'}
        )

        fig_h = go.Figure()
        for dt, color in [('Weekday','#42a5f5'),('Weekend','#ff7043')]:
            sub = hourly[hourly['day_type']==dt]
            fig_h.add_trace(go.Scatter(
                x=sub['hour'], y=sub['rides'],
                name=dt, mode='lines+markers',
                line=dict(color=color, width=2.5),
                marker=dict(size=5),
            ))

        fig_h.update_layout(
            title=dict(
                text='Ride Volume by Hour - Weekday vs Weekend',
                font=dict(color='white', size=14), x=0.5
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(
                title='Hour', gridcolor='#2a2a4a',
                tickmode='linear', dtick=2
            ),
            yaxis=dict(title='Rides', gridcolor='#2a2a4a'),
            legend=dict(bgcolor='rgba(0,0,0,0.4)'),
            height=320, hovermode='x unified',
            margin=dict(t=40, b=40),
        )
        st.plotly_chart(fig_h, use_container_width=True)

    with col2:
        # Status donut
        status_counts = filtered['status'].value_counts()
        status_colors = {
            'completed'           : '#2e7d32',
            'cancelled_by_rider'  : '#f57c00',
            'cancelled_by_driver' : '#e94560',
            'no_driver_found'     : '#c62828',
        }
        fig_s = go.Figure(go.Pie(
            labels = status_counts.index,
            values = status_counts.values,
            hole   = 0.55,
            marker = dict(colors=[
                status_colors.get(s,'#9e9e9e')
                for s in status_counts.index
            ]),
        ))
        fig_s.update_layout(
            title=dict(
                text='Ride Status Distribution',
                font=dict(color='white',size=14), x=0.5
            ),
            paper_bgcolor='#16213e',
            font=dict(color='white'),
            legend=dict(
                bgcolor='rgba(0,0,0,0.4)',
                font=dict(size=10),
            ),
            height=320,
            margin=dict(t=40,b=20,l=20,r=20),
        )
        st.plotly_chart(fig_s, use_container_width=True)

    col3, col4, col5 = st.columns(3)

    with col3:
        # Revenue by vehicle
        rev_veh = (
            filtered[filtered['status']=='completed']
            .groupby('vehicle_type')['fare_amount']
            .sum().reset_index()
            .sort_values('fare_amount', ascending=True)
        )
        veh_colors = {
            'Bike':'#42a5f5','Auto':'#ff7043',
            'EV Bike':'#66bb6a','EV Auto':'#26c6da'
        }
        fig_v = go.Figure(go.Bar(
            x = rev_veh['fare_amount'],
            y = rev_veh['vehicle_type'],
            orientation = 'h',
            marker = dict(color=[
                veh_colors.get(v,'#9e9e9e')
                for v in rev_veh['vehicle_type']
            ]),
            text = (rev_veh['fare_amount']/1e6).round(1).astype(str)+'M',
            textposition='outside',
            textfont=dict(color='white', size=10),
        ))
        fig_v.update_layout(
            title=dict(
                text='Revenue by Vehicle Type (₹)',
                font=dict(color='white',size=13), x=0.5
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=280, margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_v, use_container_width=True)

    with col4:
        # Payment mode
        pay = filtered[
            filtered['payment_mode'].notna()
        ]['payment_mode'].value_counts()
        pay_colors = {
            'UPI':'#42a5f5','Cash':'#ff7043',
            'Wallet':'#66bb6a','Card':'#ab47bc'
        }
        fig_p = go.Figure(go.Pie(
            labels=pay.index, values=pay.values,
            hole=0.5,
            marker=dict(colors=[
                pay_colors.get(p,'#9e9e9e') for p in pay.index
            ]),
        ))
        fig_p.update_layout(
            title=dict(
                text='Payment Mode Share',
                font=dict(color='white',size=13), x=0.5
            ),
            paper_bgcolor='#16213e',
            font=dict(color='white'),
            legend=dict(
                bgcolor='rgba(0,0,0,0.4)',
                font=dict(size=10),
            ),
            height=280,
            margin=dict(t=35,b=20,l=10,r=10),
        )
        st.plotly_chart(fig_p, use_container_width=True)

    with col5:
        # Monthly revenue
        mon_rev = (
            filtered[filtered['status']=='completed']
            .groupby('month')['fare_amount']
            .sum().reset_index()
        )
        fig_m = go.Figure(go.Scatter(
            x=mon_rev['month'],
            y=mon_rev['fare_amount'],
            mode='lines+markers',
            line=dict(color='#42a5f5', width=2.5),
            marker=dict(color='#e94560', size=7),
            fill='tozeroy',
            fillcolor='rgba(66,165,245,0.1)',
        ))
        fig_m.update_layout(
            title=dict(
                text='Monthly Revenue Trend (₹)',
                font=dict(color='white',size=13), x=0.5
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(
                title='Month', gridcolor='#2a2a4a',
                tickmode='linear', dtick=1,
            ),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=280,
            margin=dict(t=35,b=40,l=10,r=10),
        )
        st.plotly_chart(fig_m, use_container_width=True)

# ============================================================
# TAB 2 — ZONE INTELLIGENCE MAP
# ============================================================
with tab2:
    st.markdown("### 🗺️ H3 Hexagonal Zone Intelligence Map")

    map_col1, map_col2 = st.columns([3, 1])

    with map_col2:
        st.markdown("**Map Controls**")
        map_type = st.selectbox(
            "Map Layer",
            ["Zone Classification",
             "Demand Heatmap",
             "Repositioning Recommendations"],
        )

        filter_class = st.multiselect(
            "Show Classifications",
            options = list(ZONE_COLORS.keys()),
            default = list(ZONE_COLORS.keys()),
        )

        st.markdown("---")
        st.markdown("**Zone Classification Legend**")
        for cls, color in ZONE_COLORS.items():
            count = len(zone_map[zone_map['zone_classification']==cls])
            st.markdown(
                f'<div style="display:flex; align-items:center; '
                f'margin:3px 0; font-size:11px;">'
                f'<div style="width:14px; height:14px; '
                f'background:{color}; border-radius:2px; '
                f'margin-right:8px;"></div>'
                f'{cls} ({count})</div>',
                unsafe_allow_html=True
            )

    with map_col1:
        # Build Folium map
        m = folium.Map(
            location    = [12.9716, 77.5946],
            zoom_start  = 11,
            tiles       = "CartoDB dark_matter",
        )

        filtered_zones = zone_map[
            zone_map['zone_classification'].isin(filter_class)
        ]

        for _, row in filtered_zones.iterrows():
            try:
                boundary = h3.h3_to_geo_boundary(
                    row['h3_index'], geo_json=True
                )
                color    = ZONE_COLORS.get(
                    row['zone_classification'], '#9e9e9e'
                )
                opacity_map = {
                    'CRITICAL DEAD ZONE'   : 0.85,
                    'HIGH IDLE ZONE'       : 0.75,
                    'CRITICAL DEMAND GAP'  : 0.85,
                    'HIGH DEMAND GAP'      : 0.70,
                    'HIGH EFFICIENCY ZONE' : 0.60,
                    'BALANCED ZONE'        : 0.35,
                    'NO DRIVER DATA'       : 0.20,
                }
                opacity = opacity_map.get(
                    row['zone_classification'], 0.40
                )

                popup_html = f"""
                <div style="font-family:Arial;
                    width:220px; font-size:11px;">
                    <b style="font-size:13px;">
                        {row['zone_name']}
                    </b><br>
                    <span style="color:{color};">
                        <b>{row['zone_classification']}</b>
                    </span><br>
                    <hr style="margin:3px 0;">
                    Zone Type: {row['zone_type']}<br>
                    Total Rides: {int(row.get('total_rides',0)):,}<br>
                    Drivers: {int(row.get('drivers_in_zone',0))}<br>
                    Completion: {row.get('completion_rate',0):.1f}%<br>
                    Unmet: {row.get('unmet_rate',0):.1f}%<br>
                    Avg Wait: {row.get('avg_wait_time',0):.1f} min<br>
                    Revenue: ₹{row.get('total_revenue',0):,.0f}
                </div>
                """

                folium.Polygon(
                    locations    = [[c[1],c[0]] for c in boundary],
                    color        = color,
                    weight       = 1.5,
                    fill         = True,
                    fill_color   = color,
                    fill_opacity = opacity,
                    popup        = folium.Popup(
                        popup_html, max_width=240
                    ),
                    tooltip      = (
                        f"{row['zone_name']} | "
                        f"{row['zone_classification']}"
                    ),
                ).add_to(m)
            except:
                continue

        st_folium(m, width=800, height=520)

    # Zone stats table below map
    st.markdown("---")
    st.markdown("### Zone Intelligence Summary Table")

    display_cols = [
        'zone_name','zone_type','zone_classification',
        'total_rides','drivers_in_zone','completion_rate',
        'unmet_rate','avg_wait_time','avg_fare','total_revenue'
    ]
    display_df = zone_map[display_cols].copy()
    display_df.columns = [
        'Zone','Type','Classification',
        'Rides','Drivers','Completion%',
        'Unmet%','Wait(min)','Avg Fare','Revenue'
    ]
    display_df = display_df[
        display_df['Classification'].isin(filter_class)
    ].sort_values('Classification')

    st.dataframe(
        display_df,
        use_container_width = True,
        height              = 300,
    )

# ============================================================
# TAB 3 — DEMAND & FORECASTING
# ============================================================
with tab3:

    st.markdown("### 📈 Demand Analytics & 60-Day Forecast")

    # Forecast chart
    fig_fc = go.Figure()

    # Historical — use filtered daily rides
    daily_hist = (
        filtered.groupby('date')
        .size()
        .reset_index(name='rides')
    )

    fig_fc.add_trace(go.Scatter(
        x=daily_hist['date'], y=daily_hist['rides'],
        name='Actual Rides', mode='lines',
        line=dict(color='#42a5f5', width=1.5),
    ))

    fig_fc.add_trace(go.Scatter(
        x=forecast_df['date'],
        y=forecast_df['predicted_rides'].round(0),
        name='60-Day Forecast',
        mode='lines',
        line=dict(color='#ff7043', width=2.5, dash='dot'),
    ))

    fig_fc.add_trace(go.Scatter(
        x    = list(forecast_df['date']) +
               list(forecast_df['date'][::-1]),
        y    = list(forecast_df['upper_bound'].round(0)) +
               list(forecast_df['lower_bound'].round(0)[::-1]),
        fill = 'toself',
        fillcolor = 'rgba(255,112,67,0.12)',
        line = dict(color='rgba(0,0,0,0)'),
        name = '90% Confidence Band',
    ))

    fig_fc.add_vline(
        x=daily_hist['date'].max().timestamp()*1000,
        line_dash='dash', line_color='white', opacity=0.5,
    )

    fig_fc.update_layout(
        title=dict(
            text=(
                '🏙️ City-Wide Daily Ride Demand - '
                'Historical + 60-Day Forecast (Accuracy: 94.1%)'
            ),
            font=dict(color='white',size=15), x=0.5,
        ),
        paper_bgcolor='#16213e', plot_bgcolor='#16213e',
        font=dict(color='white'),
        xaxis=dict(title='Date', gridcolor='#2a2a4a'),
        yaxis=dict(title='Daily Rides', gridcolor='#2a2a4a'),
        legend=dict(bgcolor='rgba(0,0,0,0.4)'),
        height=380, hovermode='x unified',
        margin=dict(t=50,b=40),
    )
    st.plotly_chart(fig_fc, use_container_width=True)

    col_d1, col_d2, col_d3 = st.columns(3)

    with col_d1:
        # Weather impact on fare
        weather_fare = (
            filtered[filtered['status']=='completed']
            .groupby('weather_condition')['fare_amount']
            .mean().reset_index()
            .sort_values('fare_amount', ascending=True)
        )
        fig_wf = go.Figure(go.Bar(
            x=weather_fare['fare_amount'],
            y=weather_fare['weather_condition'],
            orientation='h',
            marker=dict(
                color=weather_fare['fare_amount'],
                colorscale='RdYlGn',
                showscale=False,
            ),
            text=weather_fare['fare_amount'].round(0),
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_wf.update_layout(
            title=dict(
                text='Avg Fare by Weather (₹)',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=320,
            margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_wf, use_container_width=True)

    with col_d2:
        # Event type rides
        event_rides = (
            filtered[filtered['active_event_type'].notna()]
            .groupby('active_event_type')
            .size().reset_index(name='rides')
            .sort_values('rides', ascending=True)
        )
        fig_ev = go.Figure(go.Bar(
            x=event_rides['rides'],
            y=event_rides['active_event_type'],
            orientation='h',
            marker=dict(color='#ab47bc'),
            text=event_rides['rides'],
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_ev.update_layout(
            title=dict(
                text='Rides by Event Type',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=320,
            margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_ev, use_container_width=True)

    with col_d3:
        # Surge by hour
        surge_hour = (
            filtered.groupby('hour')['surge_multiplier']
            .mean().reset_index()
        )
        fig_sg = go.Figure(go.Scatter(
            x=surge_hour['hour'],
            y=surge_hour['surge_multiplier'],
            mode='lines+markers',
            line=dict(color='#ffd54f', width=2.5),
            marker=dict(color='#e94560', size=6),
            fill='tozeroy',
            fillcolor='rgba(255,213,79,0.1)',
        ))
        fig_sg.update_layout(
            title=dict(
                text='Avg Surge by Hour',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(
                title='Hour', gridcolor='#2a2a4a',
                tickmode='linear', dtick=2,
            ),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=320,
            margin=dict(t=35,b=40,l=10,r=10),
        )
        st.plotly_chart(fig_sg, use_container_width=True)

# ============================================================
# TAB 4 — DRIVER INTELLIGENCE
# ============================================================
with tab4:

    st.markdown("### 🚗 Driver Intelligence & Earnings Equity")

    d1,d2,d3,d4,d5 = st.columns(5)
    d1.metric("Active Drivers",    f"{active_drivers:,}")
    d2.metric("EV Drivers",        f"{(drivers_df['is_ev']).sum():,}")
    d3.metric("Avg Rating",        f"{drivers_df['rating'].mean():.2f}")
    d4.metric("Avg Daily Earnings",f"₹{drivers_df['avg_daily_earnings'].mean():.0f}")
    d5.metric("Avg Experience",    f"{drivers_df['experience_months'].mean():.0f} mo")

    st.markdown("---")

    dcol1, dcol2, dcol3 = st.columns(3)

    with dcol1:
        veh_dist = drivers_df['vehicle_type'].value_counts()
        veh_colors_d = {
            'Bike':'#42a5f5','Auto':'#ff7043',
            'EV Bike':'#66bb6a','EV Auto':'#26c6da'
        }
        fig_vd = go.Figure(go.Pie(
            labels=veh_dist.index,
            values=veh_dist.values,
            hole=0.55,
            marker=dict(colors=[
                veh_colors_d.get(v,'#9e9e9e')
                for v in veh_dist.index
            ]),
        ))
        fig_vd.update_layout(
            title=dict(
                text='Fleet Composition',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e',
            font=dict(color='white'),
            legend=dict(bgcolor='rgba(0,0,0,0.4)'),
            height=300,
            margin=dict(t=35,b=10,l=10,r=10),
        )
        st.plotly_chart(fig_vd, use_container_width=True)

    with dcol2:
        earn_veh = (
            drivers_df.groupby('vehicle_type')
            ['avg_daily_earnings'].mean()
            .reset_index()
            .sort_values('avg_daily_earnings', ascending=True)
        )
        fig_earn = go.Figure(go.Bar(
            x=earn_veh['avg_daily_earnings'],
            y=earn_veh['vehicle_type'],
            orientation='h',
            marker=dict(color=[
                veh_colors_d.get(v,'#9e9e9e')
                for v in earn_veh['vehicle_type']
            ]),
            text=earn_veh['avg_daily_earnings'].round(0),
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_earn.update_layout(
            title=dict(
                text='Avg Daily Earnings by Vehicle (₹)',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=300,
            margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_earn, use_container_width=True)

    with dcol3:
        shift_dist = drivers_df['preferred_shift'].value_counts()
        shift_colors = {
            'evening'  :'#ab47bc',
            'morning'  :'#42a5f5',
            'afternoon':'#ff7043',
            'flexible' :'#66bb6a',
            'night'    :'#26c6da',
        }
        fig_sh = go.Figure(go.Bar(
            x=shift_dist.values,
            y=shift_dist.index,
            orientation='h',
            marker=dict(color=[
                shift_colors.get(s,'#9e9e9e')
                for s in shift_dist.index
            ]),
            text=shift_dist.values,
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_sh.update_layout(
            title=dict(
                text='Drivers by Preferred Shift',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=300,
            margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_sh, use_container_width=True)

    # Completion rate by vehicle
    comp_veh = (
        filtered.groupby('vehicle_type')
        .apply(lambda x: (x['status']=='completed').mean()*100)
        .reset_index(name='completion_rate')
        .sort_values('completion_rate', ascending=True)
    )
    fig_cv = go.Figure(go.Bar(
        x=comp_veh['completion_rate'],
        y=comp_veh['vehicle_type'],
        orientation='h',
        marker=dict(color='#26c6da'),
        text=comp_veh['completion_rate'].round(1).astype(str)+'%',
        textposition='outside',
        textfont=dict(color='white',size=11),
    ))
    fig_cv.update_layout(
        title=dict(
            text='Completion Rate by Vehicle Type (%)',
            font=dict(color='white',size=14), x=0.5,
        ),
        paper_bgcolor='#16213e', plot_bgcolor='#16213e',
        font=dict(color='white'),
        xaxis=dict(gridcolor='#2a2a4a', range=[70,85]),
        yaxis=dict(gridcolor='#2a2a4a'),
        height=260,
        margin=dict(t=40,b=30,l=10,r=80),
    )
    st.plotly_chart(fig_cv, use_container_width=True)

# ============================================================
# TAB 5 — EV & CHARGING
# ============================================================
with tab5:

    st.markdown("### ⚡ EV Fleet & Charging Network Intelligence")

    e1,e2,e3,e4,e5 = st.columns(5)
    e1.metric("Total Stations",     f"{len(stations_df)}")
    e2.metric("Operational",        f"{stations_df['is_operational'].sum()}")
    e3.metric("Avg Utilization",    f"{stations_df['avg_utilization'].mean()*100:.1f}%")
    e4.metric("Monthly Rev",        f"₹{stations_df['monthly_revenue_inr'].sum()/1e7:.2f}Cr")
    e5.metric("EV Ride Share",      f"{ev_share:.1f}%")

    st.markdown("---")

    ecol1, ecol2, ecol3 = st.columns(3)

    with ecol1:
        net_rev = (
            stations_df.groupby('network')
            ['monthly_revenue_inr'].sum()
            .reset_index()
            .sort_values('monthly_revenue_inr', ascending=True)
        )
        net_colors_map = {
            "Tata Power EV" :"#1e88e5",
            "Ather Grid"    :"#43a047",
            "Statiq"        :"#fb8c00",
            "ChargeZone"    :"#e53935",
            "BESCOM Public" :"#8e24aa",
            "Zeon Charging" :"#00acc1",
            "Rapido Internal":"#f4511e",
            "BPCL Pulse"    :"#fdd835",
        }
        fig_nr = go.Figure(go.Bar(
            x=net_rev['monthly_revenue_inr'],
            y=net_rev['network'],
            orientation='h',
            marker=dict(color=[
                net_colors_map.get(n,'#9e9e9e')
                for n in net_rev['network']
            ]),
            text=(net_rev['monthly_revenue_inr']/1e5).round(1).astype(str)+'L',
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_nr.update_layout(
            title=dict(
                text='Monthly Revenue by Network (₹)',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(gridcolor='#2a2a4a'),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=320,
            margin=dict(t=35,b=20,l=10,r=70),
        )
        st.plotly_chart(fig_nr, use_container_width=True)

    with ecol2:
        charger_dist = stations_df['charger_type'].value_counts()
        charger_colors = {
            'slow_ac'      :'#42a5f5',
            'fast_dc'      :'#ff7043',
            'ultra_fast_dc':'#e94560',
        }
        fig_cd = go.Figure(go.Pie(
            labels=[c.replace('_',' ').title() for c in charger_dist.index],
            values=charger_dist.values,
            hole=0.55,
            marker=dict(colors=[
                charger_colors.get(c,'#9e9e9e')
                for c in charger_dist.index
            ]),
        ))
        fig_cd.update_layout(
            title=dict(
                text='Stations by Charger Type',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e',
            font=dict(color='white'),
            legend=dict(bgcolor='rgba(0,0,0,0.4)'),
            height=320,
            margin=dict(t=35,b=10,l=10,r=10),
        )
        st.plotly_chart(fig_cd, use_container_width=True)

    with ecol3:
        net_util = (
            stations_df.groupby('network')
            ['avg_utilization'].mean()
            .reset_index()
            .sort_values('avg_utilization', ascending=True)
        )
        fig_nu = go.Figure(go.Bar(
            x=net_util['avg_utilization']*100,
            y=net_util['network'],
            orientation='h',
            marker=dict(
                color=net_util['avg_utilization']*100,
                colorscale='RdYlGn',
                showscale=False,
            ),
            text=(net_util['avg_utilization']*100).round(1).astype(str)+'%',
            textposition='outside',
            textfont=dict(color='white',size=10),
        ))
        fig_nu.update_layout(
            title=dict(
                text='Avg Utilization by Network (%)',
                font=dict(color='white',size=13), x=0.5,
            ),
            paper_bgcolor='#16213e', plot_bgcolor='#16213e',
            font=dict(color='white'),
            xaxis=dict(
                gridcolor='#2a2a4a', range=[0,80]
            ),
            yaxis=dict(gridcolor='#2a2a4a'),
            height=320,
            margin=dict(t=35,b=20,l=10,r=60),
        )
        st.plotly_chart(fig_nu, use_container_width=True)

    # EV rides by hour
    ev_rides_hour = (
        filtered[filtered['vehicle_type'].isin(['EV Bike','EV Auto'])]
        .groupby('hour').size().reset_index(name='ev_rides')
    )
    fig_eh = go.Figure(go.Scatter(
        x=ev_rides_hour['hour'],
        y=ev_rides_hour['ev_rides'],
        mode='lines+markers',
        line=dict(color='#66bb6a', width=2.5),
        marker=dict(color='#ffffff', size=6),
        fill='tozeroy',
        fillcolor='rgba(102,187,106,0.15)',
    ))
    fig_eh.update_layout(
        title=dict(
            text='EV Ride Demand by Hour of Day',
            font=dict(color='white',size=14), x=0.5,
        ),
        paper_bgcolor='#16213e', plot_bgcolor='#16213e',
        font=dict(color='white'),
        xaxis=dict(
            title='Hour of Day', gridcolor='#2a2a4a',
            tickmode='linear', dtick=1,
        ),
        yaxis=dict(title='EV Rides', gridcolor='#2a2a4a'),
        height=280,
        margin=dict(t=40,b=40,l=10,r=10),
    )
    st.plotly_chart(fig_eh, use_container_width=True)

# ── Footer ────────────────────────────────────────────────────
st.markdown("---")
st.markdown("""
<div style="text-align:center; color:#555; font-size:11px; padding:10px 0;">
    RapidoIQ — Urban Mobility Fleet Intelligence System |
    Bangalore 2024 | 500K Rides | 200 Zones | H3 Spatial Intelligence |
    XGBoost + SHAP | Prophet Forecasting
</div>
""", unsafe_allow_html=True)