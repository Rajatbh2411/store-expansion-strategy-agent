public without sharing class ExpansionDashboardController {
    
    @AuraEnabled(cacheable=true)
    public static List<Expansion_Site__c> getSites() {
        return [
            SELECT Id, Name, Micro_Market__c, City__c, State__c, PIN_Code__c, Address__c,
                   Latitude__c, Longitude__c, Demand_Score__c, Competition_Level__c,
                   Competition_Score__c, Competitor_Count__c, Site_Category__c, Site_Status__c,
                   Population_Density__c, Avg_Household_Income__c, Footfall_Index__c,
                   Youth_Population_Pct__c, Estimated_Monthly_Revenue__c, Estimated_Setup_Cost__c,
                   Payback_Period_Years__c, Agent_Recommendation__c, Last_Scored_Date__c
            FROM Expansion_Site__c
            ORDER BY Demand_Score__c DESC
        ];
    }
}