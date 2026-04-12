# Store Expansion Strategy Agent

> Agentforce World Tour Mumbai Hackathon 2026 — Retail & Consumer Goods Cloud

## Overview
An AI-powered Store Expansion Strategy Agent built on Salesforce Agentforce that helps the Central Planning Team identify optimal locations for new retail store openings across Mumbai metropolitan region. The agent analyzes footfall data, demographic profiles, competitor proximity, and financial metrics to recommend high-potential locations with projected success metrics.

## Demo
- **Experience Cloud Portal:** "orgfarm-a5cd43f7cf.my.site.com/expansionportal"
- **Demo Video:** [Link to video]

## Features
- **Location Recommendation** — Top expansion sites ranked by Demand Score with filtering by city, competition, and category
- **Site Scorecard Generation** — Detailed scorecards via site name, PIN code, or GPS coordinates
- **Financial Projections** — Revenue, ROI, payback period, and break-even analysis with custom input overrides
- **Blind Spot Detection** — High-demand, low-competition areas classified by opportunity tier and urgency
- **Competitive Intelligence** — Competitor analysis with threat levels, revenue estimates, and market assessment
- **Expansion Dashboard** — Interactive bubble chart (Demand vs Competition) with filters, data table, and detail view

## Technology Stack
| Component | Technology |
|---|---|
| Industry Cloud | Consumer Goods Cloud |
| AI Agent | Agentforce (Agent Builder) |
| Data Platform | Data Cloud (CRM Connector, 4 DMOs) |
| External Portal | Experience Cloud (LWR) |
| Dashboard | Lightning Web Components + Chart.js |
| Backend | Apex (5 Invocable Actions) |
| Data Model | 4 Custom Objects, 60+ Fields |

## Project Structure
```
force-app/main/default/
├── classes/
│   ├── GetTopExpansionSites.cls          # Agent Action: Location recommendations
│   ├── GetSiteScorecard.cls              # Agent Action: Site scorecard generation
│   ├── CalculateFinancialProjection.cls  # Agent Action: Financial metrics
│   ├── FindBlindSpots.cls                # Agent Action: Blind spot detection
│   ├── GetCompetitorAnalysis.cls         # Agent Action: Competitor intelligence
│   └── ExpansionDashboardController.cls  # Dashboard data controller
├── objects/
│   ├── Expansion_Site__c/                # Candidate expansion locations
│   ├── Competitor_Location__c/           # Competitor retail outlets
│   ├── Site_Scorecard__c/                # Agent-generated scorecards
│   └── Demographic_Data__c/             # Census and demographic data
├── lwc/
│   └── expansionDashboard/               # Interactive dashboard component
└── staticresources/
    └── ChartJS                           # Chart.js 4.4.0 library
```

## Agentforce Configuration
### Topics
1. **Location Recommendation** — Site rankings and scorecards
2. **Financial Projection** — Revenue, ROI, and payback analysis
3. **Competitive Intelligence** — Blind spots and competitor analysis

### Actions
| Action | Apex Class | Description |
|---|---|---|
| Get Top Expansion Sites | GetTopExpansionSites | Returns ranked site candidates |
| Get Site Scorecard | GetSiteScorecard | Generates scorecard by name/PIN/GPS |
| Calculate Financial Projection | CalculateFinancialProjection | Computes ROI, payback, profit |
| Find Blind Spots | FindBlindSpots | Identifies high-demand low-competition areas |
| Get Competitor Analysis | GetCompetitorAnalysis | Detailed competitor breakdown |

## Data
- 22 expansion site candidates across Mumbai, Thane, and Navi Mumbai
- 25+ competitor locations with brand, distance, and threat data
- 25 demographic profiles per PIN code
- Real PIN codes, GPS coordinates, and realistic financial projections

## Setup Instructions
1. Deploy metadata: `sf project deploy start --source-dir force-app`
2. Upload Chart.js as Static Resource named `ChartJS`
3. Run seed data scripts in order: Demographics → Expansion Sites → Competitors
4. Configure Agentforce Agent with 3 topics and 5 actions
5. Create Experience Cloud site and add Expansion Dashboard component
6. Connect Data Cloud CRM streams for 4 custom objects

## Test Prompts
```
Where should we open our next store in Mumbai?
Give me the scorecard for Marol Naka
What's the ROI for Powai Hiranandani?
Show me blind spots with low competition
Who are the competitors near Bandra West?
I'm at coordinates 19.0860, 72.9080 — score this location
```

## Potential Improvements
- Real-time footfall ingestion via Data Cloud Ingestion API
- WhatsApp channel for field surveyor on-site queries
- ML-based demand prediction using Einstein Discovery
- Google Maps API integration for live competitor discovery
- Automated workflow triggers on "Strongly Recommended" scorecards

## Team
Rajat Bhardwaj
Stuti Mishra
Varun Tyagi
Himanshi Kaushik

## License
Built for Agentforce World Tour Mumbai Hackathon 2026. All submissions remain the intellectual property of the developers.
