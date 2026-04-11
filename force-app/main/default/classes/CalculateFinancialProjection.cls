/**
 * CalculateFinancialProjection
 * Agentforce Action: Calculates detailed financial metrics for an expansion site.
 * Topic: Financial Projection
 */
public with sharing class CalculateFinancialProjection {

    public class FinancialRequest {
        @InvocableVariable(label='Site Name' description='Name of the expansion site' required=true)
        public String siteName;
        
        @InvocableVariable(label='Custom Setup Cost' description='Override setup cost in INR (optional)' required=false)
        public Decimal customSetupCost;
        
        @InvocableVariable(label='Custom Monthly Rent' description='Override monthly rent in INR (optional)' required=false)
        public Decimal customMonthlyRent;
        
        @InvocableVariable(label='Store Size SqFt' description='Planned store size in square feet' required=false)
        public Decimal storeSizeSqFt;
    }
    
    public class FinancialProjection {
        @InvocableVariable public String siteName;
        @InvocableVariable public Decimal estimatedMonthlyRevenue;
        @InvocableVariable public Decimal estimatedAnnualRevenue;
        @InvocableVariable public Decimal setupCost;
        @InvocableVariable public Decimal monthlyRent;
        @InvocableVariable public Decimal monthlyOperatingCost;
        @InvocableVariable public Decimal monthlyProfit;
        @InvocableVariable public Decimal annualProfit;
        @InvocableVariable public Decimal paybackPeriodYears;
        @InvocableVariable public Decimal roiPercentage;
        @InvocableVariable public Decimal breakEvenMonthlyRevenue;
        @InvocableVariable public String profitabilityRating;
        @InvocableVariable public String financialSummary;
        @InvocableVariable public Boolean found;
    }
    
    @InvocableMethod(label='Calculate Financial Projection' description='Calculates detailed financial metrics for an expansion site including revenue projection, costs, profit, ROI, and payback period. Use when user asks about revenue potential, ROI, financial viability, or payback period of a location.')
    public static List<FinancialProjection> execute(List<FinancialRequest> requests) {
        List<FinancialProjection> results = new List<FinancialProjection>();
        
        for (FinancialRequest req : requests) {
            FinancialProjection fp = new FinancialProjection();
            fp.found = false;
            
            // Search with original term first, then try each word individually
            String searchTerm = '%' + String.escapeSingleQuotes(req.siteName) + '%';
            List<Expansion_Site__c> sites = [
                SELECT Name, Demand_Score__c, Estimated_Monthly_Revenue__c, Estimated_Setup_Cost__c,
                       Avg_Household_Income__c, Footfall_Index__c, Population_Density__c
                FROM Expansion_Site__c 
                WHERE Name LIKE :searchTerm
                LIMIT 1
            ];
            // Fallback: search by first word if no match
            if (sites.isEmpty() && req.siteName.contains(' ')) {
                String firstWord = '%' + String.escapeSingleQuotes(req.siteName.split(' ')[0]) + '%';
                sites = [
                    SELECT Name, Demand_Score__c, Estimated_Monthly_Revenue__c, Estimated_Setup_Cost__c,
                           Avg_Household_Income__c, Footfall_Index__c, Population_Density__c
                    FROM Expansion_Site__c 
                    WHERE Name LIKE :firstWord
                    LIMIT 1
                ];
            }
            
            if (!sites.isEmpty()) {
                Expansion_Site__c site = sites[0];
                fp.found = true;
                fp.siteName = site.Name;
                
                // Revenue calculation - adjusted for store size if provided
                Decimal baseRevenue = site.Estimated_Monthly_Revenue__c;
                if (req.storeSizeSqFt != null && req.storeSizeSqFt > 0) {
                    Decimal sizeFactor = Math.sqrt((Double)req.storeSizeSqFt / 1500);
                    baseRevenue = baseRevenue * sizeFactor;
                }
                fp.estimatedMonthlyRevenue = baseRevenue.setScale(0);
                fp.estimatedAnnualRevenue = (baseRevenue * 12).setScale(0);
                
                // Setup cost
                fp.setupCost = (req.customSetupCost != null) ? req.customSetupCost : site.Estimated_Setup_Cost__c;
                
                // Monthly rent (15% of revenue if not provided)
                fp.monthlyRent = (req.customMonthlyRent != null) ? req.customMonthlyRent : (baseRevenue * 0.15).setScale(0);
                
                // Operating costs: rent + staff (25%) + utilities/misc (10%)
                fp.monthlyOperatingCost = (fp.monthlyRent + (baseRevenue * 0.25) + (baseRevenue * 0.10)).setScale(0);
                
                // Profit
                fp.monthlyProfit = (baseRevenue - fp.monthlyOperatingCost).setScale(0);
                fp.annualProfit = (fp.monthlyProfit * 12).setScale(0);
                
                // Payback period
                fp.paybackPeriodYears = (fp.monthlyProfit > 0) ? 
                    (fp.setupCost / (fp.monthlyProfit * 12)).setScale(1) : 0;
                
                // ROI %
                fp.roiPercentage = (fp.setupCost > 0) ? 
                    ((fp.annualProfit / fp.setupCost) * 100).setScale(1) : 0;
                
                // Break-even monthly revenue (assuming 65% gross margin)
                fp.breakEvenMonthlyRevenue = (fp.monthlyOperatingCost / 0.65).setScale(0);
                
                // Profitability rating
                if (fp.roiPercentage >= 40) fp.profitabilityRating = 'Excellent';
                else if (fp.roiPercentage >= 25) fp.profitabilityRating = 'Good';
                else if (fp.roiPercentage >= 15) fp.profitabilityRating = 'Moderate';
                else fp.profitabilityRating = 'Below Target';
                
                // Summary
                fp.financialSummary = 'Site: ' + site.Name + ' | ' +
                    'Monthly Revenue: INR ' + formatCurrency(fp.estimatedMonthlyRevenue) + ' | ' +
                    'Monthly Profit: INR ' + formatCurrency(fp.monthlyProfit) + ' | ' +
                    'Setup Cost: INR ' + formatCurrency(fp.setupCost) + ' | ' +
                    'Payback: ' + fp.paybackPeriodYears + ' years | ' +
                    'ROI: ' + fp.roiPercentage + '% | ' +
                    'Rating: ' + fp.profitabilityRating;
            }
            results.add(fp);
        }
        return results;
    }
    
    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0';
        if (amount >= 10000000) return String.valueOf((amount / 10000000).setScale(1)) + ' Cr';
        if (amount >= 100000) return String.valueOf((amount / 100000).setScale(1)) + ' L';
        return String.valueOf(amount.setScale(0));
    }
}