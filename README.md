# 📊 Business Insight 360

> *AtliQ Hardware was growing fast — revenue up 303% — but losing ground in Latin America, facing intensifying competition from Dell in core markets, and making critical decisions on data that was already a week old. Leadership needed one platform that could tell them everything. This is that platform.*

**[🚀 View Live Dashboard](https://app.powerbi.com/view?r=eyJrIjoiZjQwZWNmMDUtZDVlOS00MTM1LWE2YzQtYzExMmM0NjEzMWFmIiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)** — fully interactive, no login required

---

## 💥 What This Dashboard Revealed

These are not hypothetical insights. These are findings that emerged directly from the data — the kind that change strategic decisions:

- **$522M in operational expense** is consuming 100% of Gross Margin — Net Sales grew 303% but Net Profit is still **-11.64%**. Revenue is not the problem. Cost structure is.
- **AtliQ doubled its PC market share** from 5.9% to 9.9% in 5 years — gaining ground against Dell, BP and Innovo while the overall market stayed flat
- **LATAM contributed just 0.4% of global revenue** — far below the anticipated growth targets that triggered this entire project
- **AtliQ Exclusive customers generate 45.67% Gross Margin** vs 34.87% average — a premium channel being significantly under-invested
- **Supply Chain is chronically under-forecasting** — Net Error of -$2M, with Peripherals and Accessories carrying OOS risk that threatens $1Bn+ in potential revenue
- **71.1% of revenue flows through Retailers** — a channel concentration that compresses margins and creates negotiation vulnerability

---

## 🧭 The Business Context

AtliQ Hardware sells PCs, peripherals and accessories across **APAC, EU, North America and Latin America** through retailers, distributors and direct channels.

By late 2021, two problems were converging:

**Externally** — the LATAM market was not delivering the anticipated growth. Dell was intensifying competitive pressure in existing markets. Market share was under threat.

**Internally** — Finance, Sales, Marketing and Supply Chain were each working in separate Excel files. By the time a report reached leadership, the data was already a week old. There was no way to benchmark performance across regions, no way to spot a Gross Margin decline before it became a crisis, no way to answer: *which customer is most profitable this quarter?*

### How the Project Was Structured

Management assigned a **Product Owner** to lead the response. The Product Owner onboarded a two-person analyst team and initiated the project formally:

- 📋 **Project Charter** issued — aligning scope, objectives and stakeholder expectations
- 💬 **Microsoft Teams channel** set up — Product Owner, Senior DA (Lead) and DA (myself)
- 🖼️ **Mockups created per view** — signed off before any build began
- 🔄 **Stakeholder review rounds** — feedback incorporated iteratively throughout the build

The result: **Business Insight 360** — five views, every stakeholder covered, one platform.

---

## 🎯 Dashboard Views at a Glance

| View | Built For | Core Question Answered |
|------|-----------|----------------------|
| 💰 Finance | CFO, Finance Team | Are we ahead or behind on P&L — and why? |
| 🤝 Sales | Sales Director, Account Managers | Which customers and products are making us money? |
| 📣 Marketing | Marketing Manager, Product Team | Which segments and markets are actually profitable? |
| 🚛 Supply Chain | SC Manager, Procurement | Are we forecasting correctly — and where is the risk? |
| 🏆 Executive | CEO, Board | What is the one-page view of our entire business? |

### 💰 Finance View

![Finance](screenshots/finance.jpg)

The full P&L statement from Gross Sales to Net Profit % — benchmarkable against Last Year or Target with a single toggle. The step-line trend chart shows **exactly when revenue changed**, not a misleading smooth curve. Field Parameters enable drill-through from Region → Market → Product in one visual.

> *Before this dashboard: assembling the P&L took hours across multiple Excel files. Now: 3 seconds.*

---

### 🤝 Sales View

![Sales](screenshots/sales.jpg)

A performance scatter matrix plots every customer by Net Sales vs Gross Margin % — ideal customers sit top-right. The Customer ↔ Product toggle is built with **Field Parameters** — one table, two dimensions, zero duplication. GM% inline data bars let the Sales team scan profitability at a glance without reading every number.

> *Before this dashboard: no one knew AtliQ Exclusive was generating 11 percentage points more margin than average. Now: it's the first thing you see.*

---

### 📣 Marketing View

![Marketing](screenshots/Marketing.jpg)

Two toggle techniques on one page: a **Bookmark button** swaps the scatter chart Y-axis between NP% and GM%, and a **Selection Pane + Grouping** toggle switches the table between Segment and Market. Conditional formatting on ΔNP% fires red bars on any segment declining vs benchmark — instant visual alert, no reading required.

> *The grouping technique was critical here — without it, repositioning visuals broke the bookmarks. A real-world problem with a real-world fix.*

---

### 🚛 Supply Chain View

![Supply Chain](screenshots/supply_chain.jpg)

Forecast Accuracy %, Net Error and Absolute Error KPIs — each with Last Year comparison and directional arrow. Net Error bars are colour-coded: **gold for over-forecast, red for under-forecast**. Every customer and product segment is flagged EI (Excess Inventory) or OOS (Out of Stock risk) — directly driving replenishment decisions.

> *This view is the most operationally actionable page in the dashboard. A Supply Chain Manager can open it on Monday morning and know exactly where to focus.*

---

### 🏆 Executive View

![Executive](screenshots/executive.jpg)

Four KPI cards with embedded sparklines — value, benchmark delta and trend direction in one card. The PC market share trend shows AtliQ's 5-year growth story against four named competitors. A Revenue toggle switches between Division and Channel splits. The Sub-Region scorecard gives the CEO a global view across 7 regions in one table.

> *Previously this view required pulling from five different sources. Now it refreshes automatically.*

---

## ⚙️ How It Was Built

### Data Pipeline

```
MySQL Database → Power BI (Direct Connection)
      ↓
Power Query (Transform & Clean)
      ↓
Star Schema Data Model
      ↓
DAX Measures (50+)
      ↓
Power BI Service (Published & Live)
```

### Data Model — Star Schema

![Data Model](screenshots/data_model.jpg)

Two fact tables (`fact_actuals_estimates`, `fact_forecast_monthly`) connected to dimension tables (`dim_customer`, `dim_product`, `dim_market`, `dim_date`) via primary and foreign keys. Support tables (`P&L Rows/Columns`, `NsGm Target`, `Set BM`) power the dynamic P&L layout and benchmark toggle logic.

### DAX — Key Measure Categories

Full documented code in [`dax/measures.md`](dax/Measures.md)

| Category | Measures |
|----------|---------|
| Revenue | Gross Sales, Net Invoice Sales, Net Sales $, Revenue Contribution % |
| Profitability | Gross Margin $, Gross Margin %, Net Profit $, Net Profit %, GM/Unit |
| Supply Chain | Forecast Accuracy %, Net Error, Absolute Error, Risk Classification |
| Benchmarking | vs LY (CALCULATE), vs Target, Chg $, Chg % (DIVIDE) |

### Advanced Techniques

| Technique | Where | Why It Was Needed |
|-----------|-------|-------------------|
| **Field Parameters** | Finance, Sales, Marketing | Stakeholder requested one table to switch between Customer and Product — no duplication |
| **Bookmarks + Buttons** | Sales, Marketing, Executive | Toggle between two visuals with a single button click |
| **Selection Pane + Grouping** | Marketing | Grouping preserved bookmark integrity when visuals were repositioned |
| **Step-Line Charts** | Finance, Supply Chain | Accurately shows *when* values changed — smooth curves imply gradual shifts that didn't happen |
| **Conditional Formatting** | All views | Instant risk signals — red always means problem, green always means positive |
| **Sparklines in KPI Cards** | Executive | Trend direction alongside the headline number — context the CEO needs |
| **Dynamic P&L via Support Tables** | Finance | P&L layout fully configurable without rebuilding the visual |

---

## 📁 Repository Structure

```
Business-Insight-360/
│
├── README.md
├── dashboard/
│   └── Business_Insight_360.pbix
├── screenshots/
│   ├── home.png
│   ├── finance.png
│   ├── sales.png
│   ├── marketing.png
│   ├── supply_chain.png
│   └── executive.png
├── dax/
│   └── measures.md
├── presentation/
│   └── BI360_Story_Presentation.pptx
└── docs/
    └── data_model.png
```

---

## 🚀 Explore the Project

| What | Where |
|------|-------|
| 🖥️ Live Dashboard | **[Open in Power BI Service](https://app.powerbi.com/view?r=eyJrIjoiZjQwZWNmMDUtZDVlOS00MTM1LWE2YzQtYzExMmM0NjEzMWFmIiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)** |
| 📁 Power BI File | `dashboard/Business_Insight_360.pbix` |
| 📐 DAX Measures | `dax/measures.md` |
| 🎞️ Project Presentation | `presentation/BI360_Story_Presentation.pptx` |
| 🗄️ Data Model | `docs/data_model.png` |

---

## 👤 About Me

I'm **Harshil Patel** — a data professional based in the **Netherlands**, currently completing an MBA with a specialisation in Data Analytics.

My background is in commercial sales (Bever, NL) and manufacturing (LED lighting startup, India) — which means I approach data not just as a technical exercise, but as a tool for making better business decisions. That perspective shaped every design choice in this dashboard.

I'm actively looking for **Data Analyst roles in the Netherlands**, with particular interest in **logistics, supply chain and commercial analytics** — sectors where the Dutch market leads globally.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=flat&logo=linkedin)](https://www.linkedin.com/in/harshil-patel-188b2274/)
[![GitHub](https://img.shields.io/badge/GitHub-HP85--NL-181717?style=flat&logo=github)](https://github.com/HP85-NL)
[![Live Dashboard](https://img.shields.io/badge/Power%20BI-Live%20Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)](https://app.powerbi.com/view?r=eyJrIjoiZjQwZWNmMDUtZDVlOS00MTM1LWE2YzQtYzExMmM0NjEzMWFmIiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)

---

*Data sourced from the AtliQ allowed only unitl 2022 to show. Built for the Netherlands data analytics job market.*
