# Automated Production Planning System

An intelligent production scheduling system that optimizes manufacturing plans based on demand forecasts and capacity constraints, minimizing both backlog and excess inventory.

## Project Overview

This system automates weekly production planning by:
- Analyzing demand forecasts and daily production capacities
- Generating optimal production release schedules
- Minimizing backlog while avoiding excess inventory buildup
- Providing visual analytics for production performance monitoring

## Key Features

- **Dynamic Input**: Excel-based demand and capacity configuration
- **Intelligent Scheduling**: Automated production release planning
- **Backlog Management**: Real-time tracking and minimization
- **Inventory Optimization**: Balance between stockouts and excess stock
- **Visual Analytics**: Comprehensive dashboards for production insights
- **Scalable Planning**: Support for multi-week rolling forecasts

## Dashboard Analytics

The system generates comprehensive visualizations including:

1. **Weekly Capacity vs Production** - Resource utilization tracking
2. **Backlog Analysis** - Weekly backlog trends and hotspots
3. **Inventory Levels** - Stock accumulation by week
4. **Daily Capacity Utilization** - Efficiency metrics over time
5. **Top 5 Production Items** - Forward and backward production analysis
6. **Demand vs Production Tracking** - Per-product performance (top 3 items)
7. **Inventory Movement** - Stock trend analysis (top 3 items)

## Technical Stack

- **MATLAB R2020+** - Core optimization and analytics engine
- **Excel** - Input/output data interface
- **Optimization Algorithms** - Custom scheduling heuristics

## Project Structure

```
Production-Planning-System/
├── dugorocni_plan.m                    # Main planning algorithm
├── input_data.xlsx                     # Demand & capacity input
├── poboljsani_plan_YYYY-MM-DD.xlsx    # Generated production schedule
└── poboljsani_plan_grafika.png        # Analytics dashboard
```

## Usage

### Step 1: Prepare Input Data
Create or update `input_data.xlsx` with:
- **Demand Sheet**: Weekly demand forecasts per product (PN)
- **Capacity Sheet**: Daily production capacity per product

The system supports rolling forecasts - you can extend planning horizon by adding more weeks.

### Step 2: Run Planning Algorithm
```matlab
% In MATLAB
run dugorocni_plan.m
```

### Step 3: Review Results

The system generates:
- `poboljsani_plan_YYYY-MM-DD_HHMM.xlsx` - Detailed production schedule with:
  - Planned Release dates
  - Production quantities
  - Backlog status
  - Forward production flags
  
- `poboljsani_plan_grafika.png` - Visual analytics dashboard

## Algorithm Logic

1. **Data Import**: Load demand forecasts and capacity constraints
2. **Schedule Optimization**:
   - Prioritize backlog reduction
   - Avoid unnecessary forward production (minimize WIP)
   - Respect daily capacity limits
   - Balance across multiple product numbers (PNs)
3. **Release Planning**: Calculate optimal production start dates
4. **Performance Analysis**: Generate metrics and visualizations
5. **Export**: Save detailed schedules and executive dashboards

## Business Benefits

- **Reduced Backlog**: Intelligent prioritization minimizes delays
- **Lower Inventory Costs**: Avoid overproduction and excess WIP
- **Capacity Optimization**: Maximum utilization without overload
- **Proactive Planning**: Visual early warnings for bottlenecks
- **Data-Driven Decisions**: Clear metrics for production management

## Applications

- Manufacturing production planning
- Supply chain operations
- Capacity planning and management
- Demand-driven scheduling
- Lean manufacturing optimization

## Key Learnings

- Production planning optimization techniques
- Capacity-constrained scheduling
- Backlog vs. inventory trade-off management
- Data visualization for operations management
- MATLAB data processing and analytics

## Author

**Danilo Lazović**
- Production Planning Specialist @ BOSCH (Jan 2026 - Present)
- Student of Management and Organization - Operations Management
- Faculty of Organizational Sciences, University of Belgrade

## License

This project is available for educational and research purposes.

---

**Note**: This system was developed to solve real-world production planning challenges, demonstrating practical applications of operations research and optimization theory.
