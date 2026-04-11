/**
 * GetTopExpansionSites
 * Agentforce Action: Returns highest-ranked expansion site candidates.
 * Topic: Location Recommendation
 */
public with sharing class GetTopExpansionSites {

    public class TopSitesRequest {
        @InvocableVariable(label='City' description='City to filter sites (e.g., Mumbai, Thane, Navi Mumbai)' required=false)
        public String city;
        
        @InvocableVariable(label='Maximum Competition Level' description='Filter by max competition: Low, Medium, or High' required=false)
        public String maxCompetitionLevel;
        
        @InvocableVariable(label='Minimum Demand Score' description='Minimum demand score threshold (0-100)' required=false)
        public Decimal minDemandScore;
        
        @InvocableVariable(label='Maximum Payback Period Years' description='Maximum acceptable payback period in years' required=false)
        public Decimal maxPaybackYears;
        
        @InvocableVariable(label='Number of Results' description='How many top sites to return (default 5)' required=false)
        public Integer topN;
        
        @InvocableVariable(label='Site Category' description='Filter by category: High Street, Mall, Residential Hub, Transit Corridor, Commercial District' required=false)
        public String siteCategory;
    }
    
    public class SiteRecommendation {
        @InvocableVariable public String siteName;
        @InvocableVariable public String microMarket;
        @InvocableVariable public String city;
        @InvocableVariable public String pinCode;
        @InvocableVariable public Decimal demandScore;
        @InvocableVariable public String competitionLevel;
        @InvocableVariable public Decimal competitionScore;
        @InvocableVariable public Decimal overallScore;
        @InvocableVariable public Decimal estimatedMonthlyRevenue;
        @InvocableVariable public Decimal paybackPeriodYears;
        @InvocableVariable public Decimal estimatedSetupCost;
        @InvocableVariable public Integer competitorCount;
        @InvocableVariable public String siteCategory;
        @InvocableVariable public String siteStatus;
        @InvocableVariable public String agentRecommendation;
        @InvocableVariable public String address;
        @InvocableVariable public Boolean isBlindSpot;
    }
    
    @InvocableMethod(label='Get Top Expansion Sites' description='Returns the highest-ranked expansion site candidates based on demand score, competition, and financial metrics. Use this when the user asks for location recommendations, where to open the next store, or top sites for expansion.')
    public static List<List<SiteRecommendation>> execute(List<TopSitesRequest> requests) {
        List<List<SiteRecommendation>> results = new List<List<SiteRecommendation>>();
        
        for (TopSitesRequest req : requests) {
            Integer limitN = (req.topN != null && req.topN > 0) ? req.topN : 5;
            Decimal minScore = (req.minDemandScore != null) ? req.minDemandScore : 0;
            Decimal maxPayback = (req.maxPaybackYears != null) ? req.maxPaybackYears : 999;
            
            // Build dynamic query
            String query = 'SELECT Name, Micro_Market__c, City__c, PIN_Code__c, Address__c, ' +
                'Demand_Score__c, Competition_Level__c, Competition_Score__c, ' +
                'Estimated_Monthly_Revenue__c, Payback_Period_Years__c, Estimated_Setup_Cost__c, ' +
                'Competitor_Count__c, Site_Category__c, Site_Status__c, Agent_Recommendation__c ' +
                'FROM Expansion_Site__c WHERE Demand_Score__c >= ' + minScore +
                ' AND Payback_Period_Years__c <= ' + maxPayback;
            
            if (String.isNotBlank(req.city)) {
                query += ' AND City__c = \'' + String.escapeSingleQuotes(req.city) + '\'';
            }
            if (String.isNotBlank(req.maxCompetitionLevel)) {
                List<String> levels = getCompetitionLevels(req.maxCompetitionLevel);
                query += ' AND Competition_Level__c IN (' + joinForIN(levels) + ')';
            }
            if (String.isNotBlank(req.siteCategory)) {
                query += ' AND Site_Category__c = \'' + String.escapeSingleQuotes(req.siteCategory) + '\'';
            }
            
            query += ' ORDER BY Demand_Score__c DESC LIMIT ' + limitN;
            
            List<Expansion_Site__c> sites = Database.query(query);
            List<SiteRecommendation> recs = new List<SiteRecommendation>();
            
            for (Expansion_Site__c s : sites) {
                SiteRecommendation rec = new SiteRecommendation();
                rec.siteName = s.Name;
                rec.microMarket = s.Micro_Market__c;
                rec.city = s.City__c;
                rec.pinCode = s.PIN_Code__c;
                rec.address = s.Address__c;
                rec.demandScore = s.Demand_Score__c;
                rec.competitionLevel = s.Competition_Level__c;
                rec.competitionScore = s.Competition_Score__c;
                rec.overallScore = (s.Demand_Score__c * 0.6) + ((100 - (s.Competition_Score__c != null ? s.Competition_Score__c : 0)) * 0.4);
                rec.estimatedMonthlyRevenue = s.Estimated_Monthly_Revenue__c;
                rec.paybackPeriodYears = s.Payback_Period_Years__c;
                rec.estimatedSetupCost = s.Estimated_Setup_Cost__c;
                rec.competitorCount = (s.Competitor_Count__c != null) ? s.Competitor_Count__c.intValue() : 0;
                rec.siteCategory = s.Site_Category__c;
                rec.siteStatus = s.Site_Status__c;
                rec.agentRecommendation = s.Agent_Recommendation__c;
                rec.isBlindSpot = (s.Demand_Score__c >= 75 && s.Competition_Level__c == 'Low');
                recs.add(rec);
            }
            results.add(recs);
        }
        return results;
    }
    
    private static List<String> getCompetitionLevels(String maxLevel) {
        if (maxLevel == 'Low') return new List<String>{'Low'};
        if (maxLevel == 'Medium') return new List<String>{'Low', 'Medium'};
        return new List<String>{'Low', 'Medium', 'High'};
    }
    
    private static String joinForIN(List<String> vals) {
        List<String> quoted = new List<String>();
        for (String v : vals) quoted.add('\'' + String.escapeSingleQuotes(v) + '\'');
        return String.join(quoted, ',');
    }
}