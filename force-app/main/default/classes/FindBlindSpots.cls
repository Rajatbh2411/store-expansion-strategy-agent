/**
 * FindBlindSpots
 * Agentforce Action: Identifies high-demand areas with low competition.
 * Topic: Competitive Intelligence
 */
public with sharing class FindBlindSpots {

    public class BlindSpotRequest {
        @InvocableVariable(label='City' description='City to search (optional, defaults to all)' required=false)
        public String city;
        
        @InvocableVariable(label='Minimum Demand Score' description='Minimum demand score for blind spot (default 70)' required=false)
        public Decimal minDemandScore;
        
        @InvocableVariable(label='Maximum Competitors' description='Maximum competitor count to qualify as blind spot (default 3)' required=false)
        public Integer maxCompetitors;
    }
    
    public class BlindSpotResult {
        @InvocableVariable public String siteName;
        @InvocableVariable public String microMarket;
        @InvocableVariable public String city;
        @InvocableVariable public String pinCode;
        @InvocableVariable public Decimal demandScore;
        @InvocableVariable public Integer competitorCount;
        @InvocableVariable public Decimal estimatedMonthlyRevenue;
        @InvocableVariable public Decimal paybackPeriodYears;
        @InvocableVariable public Decimal populationGrowthRate;
        @InvocableVariable public String opportunity;
        @InvocableVariable public String urgency;
        @InvocableVariable public String address;
    }
    
    @InvocableMethod(label='Find Blind Spots' description='Identifies high-demand areas with low competition where the brand has no presence but significant consumer demand exists. Use when user asks about untapped markets, blind spots, gaps in coverage, or areas with low competition and high demand.')
    public static List<List<BlindSpotResult>> execute(List<BlindSpotRequest> requests) {
        List<List<BlindSpotResult>> results = new List<List<BlindSpotResult>>();
        
        for (BlindSpotRequest req : requests) {
            Decimal minScore = (req.minDemandScore != null) ? req.minDemandScore : 70;
            Integer maxComp = (req.maxCompetitors != null) ? req.maxCompetitors : 3;
            
            String query = 'SELECT Name, Micro_Market__c, City__c, PIN_Code__c, Address__c, ' +
                'Demand_Score__c, Competitor_Count__c, Estimated_Monthly_Revenue__c, Payback_Period_Years__c ' +
                'FROM Expansion_Site__c ' +
                'WHERE Demand_Score__c >= ' + minScore + ' AND Competition_Level__c = \'Low\' ' +
                'AND Competitor_Count__c <= ' + maxComp;
            
            if (String.isNotBlank(req.city)) {
                query += ' AND City__c = \'' + String.escapeSingleQuotes(req.city) + '\'';
            }
            query += ' ORDER BY Demand_Score__c DESC';
            
            List<Expansion_Site__c> sites = Database.query(query);
            List<BlindSpotResult> blindSpots = new List<BlindSpotResult>();
            
            // Get demographic growth data
            Set<String> pinCodes = new Set<String>();
            for (Expansion_Site__c s : sites) pinCodes.add(s.PIN_Code__c);
            
            Map<String, Decimal> growthMap = new Map<String, Decimal>();
            for (Demographic_Data__c d : [
                SELECT PIN_Code__c, Growth_Rate_Pct__c 
                FROM Demographic_Data__c 
                WHERE PIN_Code__c IN :pinCodes
            ]) {
                growthMap.put(d.PIN_Code__c, d.Growth_Rate_Pct__c);
            }
            
            for (Expansion_Site__c s : sites) {
                BlindSpotResult bs = new BlindSpotResult();
                bs.siteName = s.Name;
                bs.microMarket = s.Micro_Market__c;
                bs.city = s.City__c;
                bs.pinCode = s.PIN_Code__c;
                bs.address = s.Address__c;
                bs.demandScore = s.Demand_Score__c;
                bs.competitorCount = (s.Competitor_Count__c != null) ? s.Competitor_Count__c.intValue() : 0;
                bs.estimatedMonthlyRevenue = s.Estimated_Monthly_Revenue__c;
                bs.paybackPeriodYears = s.Payback_Period_Years__c;
                bs.populationGrowthRate = growthMap.containsKey(s.PIN_Code__c) ? growthMap.get(s.PIN_Code__c) : 0;
                
                // Classify opportunity tier
                if (s.Demand_Score__c >= 85) bs.opportunity = 'Premium Blind Spot';
                else if (s.Demand_Score__c >= 75) bs.opportunity = 'High-Value Blind Spot';
                else bs.opportunity = 'Emerging Blind Spot';
                
                // Classify urgency based on population growth
                Decimal growth = bs.populationGrowthRate;
                if (growth >= 6) bs.urgency = 'Act Now - Rapid Growth';
                else if (growth >= 4) bs.urgency = 'High Priority';
                else bs.urgency = 'Monitor & Plan';
                
                blindSpots.add(bs);
            }
            results.add(blindSpots);
        }
        return results;
    }
}