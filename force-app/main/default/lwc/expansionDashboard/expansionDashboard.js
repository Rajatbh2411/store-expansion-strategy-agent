import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getSites from '@salesforce/apex/ExpansionDashboardController.getSites';
import chartjs from '@salesforce/resourceUrl/ChartJS';

const COLUMNS = [
    { label: 'Site Name', fieldName: 'name', type: 'text', sortable: true },
    { label: 'Micro Market', fieldName: 'microMarket', type: 'text', sortable: true },
    { label: 'City', fieldName: 'city', type: 'text', sortable: true },
    { label: 'Category', fieldName: 'category', type: 'text', sortable: true },
    { label: 'Demand Score', fieldName: 'demandScore', type: 'number', sortable: true, 
      cellAttributes: { alignment: 'center' } },
    { label: 'Competition', fieldName: 'competitionLevel', type: 'text', sortable: true,
      cellAttributes: { alignment: 'center' } },
    { label: 'Competitors', fieldName: 'competitorCount', type: 'number', sortable: true,
      cellAttributes: { alignment: 'center' } },
    { label: 'Monthly Revenue (₹)', fieldName: 'monthlyRevenue', type: 'currency', sortable: true,
      typeAttributes: { currencyCode: 'INR' } },
    { label: 'Payback (Yrs)', fieldName: 'paybackYears', type: 'number', sortable: true,
      typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 },
      cellAttributes: { alignment: 'center' } },
    { label: 'Blind Spot', fieldName: 'blindSpotLabel', type: 'text', sortable: true,
      cellAttributes: { alignment: 'center' } },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'View Details', name: 'view' }] } }
];

export default class ExpansionDashboard extends LightningElement {
    @track sites = [];
    @track filteredSites = [];
    @track selectedSite = null;
    @track selectedCity = '';
    @track selectedCompetition = '';
    @track selectedCategory = '';
    @track selectedView = 'chart';
    @track sortedBy = 'demandScore';
    @track sortedDirection = 'desc';
    
    columns = COLUMNS;
    chartjsLoaded = false;
    chart = null;
    error;

    // Filter options
    get cityOptions() {
        let cities = [...new Set(this.sites.map(s => s.City__c))].filter(Boolean).sort();
        let opts = [{ label: 'All Cities', value: '' }];
        cities.forEach(c => opts.push({ label: c, value: c }));
        return opts;
    }

    get competitionOptions() {
        return [
            { label: 'All Levels', value: '' },
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' }
        ];
    }

    get categoryOptions() {
        let cats = [...new Set(this.sites.map(s => s.Site_Category__c))].filter(Boolean).sort();
        let opts = [{ label: 'All Categories', value: '' }];
        cats.forEach(c => opts.push({ label: c, value: c }));
        return opts;
    }

    get viewOptions() {
        return [
            { label: 'Bubble Chart', value: 'chart' },
            { label: 'Data Table', value: 'table' }
        ];
    }

    // View toggles
    get showChart() { return this.selectedView === 'chart' && !this.showDetail; }
    get showTable() { return this.selectedView === 'table' && !this.showDetail; }
    get showDetail() { return this.selectedSite !== null; }

    // Summary metrics
    get totalSites() { return this.filteredSites.length; }
    
    get blindSpotCount() {
        return this.filteredSites.filter(s => s.Demand_Score__c >= 75 && s.Competition_Level__c === 'Low').length;
    }
    
    get avgDemandScore() {
        if (!this.filteredSites.length) return '0';
        let avg = this.filteredSites.reduce((sum, s) => sum + (s.Demand_Score__c || 0), 0) / this.filteredSites.length;
        return avg.toFixed(1);
    }
    
    get avgPayback() {
        if (!this.filteredSites.length) return '0';
        let avg = this.filteredSites.reduce((sum, s) => sum + (s.Payback_Period_Years__c || 0), 0) / this.filteredSites.length;
        return avg.toFixed(1);
    }

    // Selected site computed fields
    get selectedSiteRevenue() {
        return this.selectedSite ? this.formatINR(this.selectedSite.Estimated_Monthly_Revenue__c) : '';
    }
    get selectedSiteSetupCost() {
        return this.selectedSite ? this.formatINR(this.selectedSite.Estimated_Setup_Cost__c) : '';
    }
    get selectedSiteIsBlindSpot() {
        return this.selectedSite && this.selectedSite.Demand_Score__c >= 75 && this.selectedSite.Competition_Level__c === 'Low';
    }

    // Table data
    get filteredTableData() {
        let data = this.filteredSites.map(s => ({
            id: s.Id,
            name: s.Name,
            microMarket: s.Micro_Market__c,
            city: s.City__c,
            category: s.Site_Category__c,
            demandScore: s.Demand_Score__c,
            competitionLevel: s.Competition_Level__c,
            competitorCount: s.Competitor_Count__c,
            monthlyRevenue: s.Estimated_Monthly_Revenue__c,
            paybackYears: s.Payback_Period_Years__c,
            blindSpotLabel: (s.Demand_Score__c >= 75 && s.Competition_Level__c === 'Low') ? '🔥 Yes' : 'No',
            status: s.Site_Status__c
        }));

        if (this.sortedBy) {
            data.sort((a, b) => {
                let valA = a[this.sortedBy] || '';
                let valB = b[this.sortedBy] || '';
                let result = 0;
                if (typeof valA === 'number') result = valA - valB;
                else result = String(valA).localeCompare(String(valB));
                return this.sortedDirection === 'asc' ? result : -result;
            });
        }
        return data;
    }

    @wire(getSites)
    wiredSites({ error, data }) {
        if (data) {
            this.sites = data;
            this.applyFilters();
        } else if (error) {
            this.error = error;
            console.error('Error loading sites:', error);
        }
    }

    renderedCallback() {
        if (this.chartjsLoaded) {
            if (this.showChart) this.renderChart();
            return;
        }
        loadScript(this, chartjs)
            .then(() => {
                this.chartjsLoaded = true;
                if (this.showChart) this.renderChart();
            })
            .catch(err => console.error('ChartJS load error:', err));
    }

    applyFilters() {
        let filtered = [...this.sites];
        if (this.selectedCity) filtered = filtered.filter(s => s.City__c === this.selectedCity);
        if (this.selectedCompetition) filtered = filtered.filter(s => s.Competition_Level__c === this.selectedCompetition);
        if (this.selectedCategory) filtered = filtered.filter(s => s.Site_Category__c === this.selectedCategory);
        this.filteredSites = filtered;
        this.selectedSite = null;
    }

    renderChart() {
        const canvas = this.template.querySelector('canvas.bubble-chart');
        if (!canvas || !this.filteredSites.length) return;

        if (this.chart) {
            this.chart.destroy();
        }

        const ctx = canvas.getContext('2d');

        // Group by competition level
        const lowComp = [], medComp = [], highComp = [], blindSpots = [];

        this.filteredSites.forEach(s => {
            const point = {
                x: s.Competition_Score__c || 0,
                y: s.Demand_Score__c || 0,
                r: Math.max(((s.Estimated_Monthly_Revenue__c || 0) / 500000), 5),
                label: s.Name,
                payback: s.Payback_Period_Years__c
            };

            const isBlind = s.Demand_Score__c >= 75 && s.Competition_Level__c === 'Low';
            if (isBlind) blindSpots.push(point);
            else if (s.Competition_Level__c === 'Low') lowComp.push(point);
            else if (s.Competition_Level__c === 'Medium') medComp.push(point);
            else highComp.push(point);
        });

        this.chart = new window.Chart(ctx, {
            type: 'bubble',
            data: {
                datasets: [
                    { label: 'Low Competition', data: lowComp, backgroundColor: 'rgba(76, 175, 80, 0.6)', borderColor: 'rgba(76, 175, 80, 1)', borderWidth: 1 },
                    { label: 'Medium Competition', data: medComp, backgroundColor: 'rgba(255, 193, 7, 0.6)', borderColor: 'rgba(255, 193, 7, 1)', borderWidth: 1 },
                    { label: 'High Competition', data: highComp, backgroundColor: 'rgba(244, 67, 54, 0.6)', borderColor: 'rgba(244, 67, 54, 1)', borderWidth: 1 },
                    { label: 'Blind Spot', data: blindSpots, backgroundColor: 'rgba(33, 150, 243, 0.7)', borderColor: 'rgba(33, 150, 243, 1)', borderWidth: 2 }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { title: { display: true, text: 'Competition Score →', font: { size: 14 } }, min: 0, max: 100 },
                    y: { title: { display: true, text: '← Demand Score', font: { size: 14 } }, min: 50, max: 100 }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: function(ctx) {
                                const d = ctx.raw;
                                return [
                                    d.label,
                                    'Demand: ' + d.y + '/100',
                                    'Competition: ' + d.x + '/100',
                                    'Payback: ' + d.payback + ' yrs'
                                ];
                            }
                        }
                    }
                }
            }
        });
    }

    // Event handlers
    handleCityChange(e) { this.selectedCity = e.detail.value; this.applyFilters(); }
    handleCompetitionChange(e) { this.selectedCompetition = e.detail.value; this.applyFilters(); }
    handleCategoryChange(e) { this.selectedCategory = e.detail.value; this.applyFilters(); }
    
    handleViewChange(e) {
        this.selectedView = e.detail.value;
        if (this.selectedView === 'chart') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.renderChart(), 100);
        }
    }

    handleSort(e) {
        this.sortedBy = e.detail.fieldName;
        this.sortedDirection = e.detail.sortDirection;
    }

    handleRowAction(e) {
        const row = e.detail.row;
        this.selectedSite = this.sites.find(s => s.Id === row.id);
    }

    handleBackToList() {
        this.selectedSite = null;
        if (this.selectedView === 'chart') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.renderChart(), 100);
        }
    }

    formatINR(amount) {
        if (!amount) return '0';
        if (amount >= 10000000) return (amount / 10000000).toFixed(1) + ' Cr';
        if (amount >= 100000) return (amount / 100000).toFixed(1) + ' L';
        return amount.toLocaleString('en-IN');
    }
}