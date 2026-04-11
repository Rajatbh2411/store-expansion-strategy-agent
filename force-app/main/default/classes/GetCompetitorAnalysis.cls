/**
 * GetCompetitorAnalysis
 * Agentforce Action: Provides detailed competitive intelligence for a site.
 * Topic: Competitive Intelligence
 */
public with sharing class GetCompetitorAnalysis {

    public class CompetitorRequest {
        @InvocableVariable(label='Site Name or Micro Market' description='Name of expansion site or micro-market to analyze competitors for' required=true)
        public String siteNameOrMarket;
    }
    
    public class CompetitorAnalysis {
        @InvocableVariable public String siteName;
        @InvocableVariable public Integer totalCompetitors;
        @InvocableVariable public Integer directCompetitors;
        @InvocableVariable public Integer indirectCompetitors;
        @InvocableVariable public Integer highThreatCount;
        @InvocableVariable public String nearestCompetitor;
        @InvocableVariable public Decimal nearestCompetitorDistance;
        @InvocableVariable public Decimal avgCompetitorRevenue;
        @InvocableVariable public Decimal totalMarketRevenue;
        @InvocableVariable public String competitorDetails;
        @InvocableVariable public String marketAssessment;
        @InvocableVariable public Boolean found;
    }
    
    @InvocableMethod(label='Get Competitor Analysis' description='Provides detailed competitive intelligence for a specific site or micro-market, including competitor count by type, threat levels, revenue estimates, nearest competitor, and overall market assessment. Use when user asks about competition in a specific area or wants to know who the competitors are.')
    public static List<CompetitorAnalysis> execute(List<CompetitorRequest> requests) {
        List<CompetitorAnalysis> results = new List<CompetitorAnalysis>();
        
        for (CompetitorRequest req : requests) {
            CompetitorAnalysis ca = new CompetitorAnalysis();
            ca.found = false;
            
            String searchTerm = '%' + String.escapeSingleQuotes(req.siteNameOrMarket) + '%';
            List<Expansion_Site__c> sites = [
                SELECT Id, Name FROM Expansion_Site__c 
                WHERE Name LIKE :searchTerm OR Micro_Market__c LIKE :searchTerm
                LIMIT 1
            ];
            
            if (!sites.isEmpty()) {
                ca.found = true;
                ca.siteName = sites[0].Name;
                
                List<Competitor_Location__c> competitors = [
                    SELECT Brand_Name__c, Category__c, Store_Type__c, Distance_From_Site_Km__c,
                           Estimated_Revenue__c, Store_Size_SqFt__c, Year_Established__c, Threat_Level__c
                    FROM Competitor_Location__c 
                    WHERE Expansion_Site__c = :sites[0].Id
                    ORDER BY Distance_From_Site_Km__c ASC
                ];
                
                ca.totalCompetitors = competitors.size();
                ca.directCompetitors = 0;
                ca.indirectCompetitors = 0;
                ca.highThreatCount = 0;
                Decimal totalRev = 0;
                List<String> details = new List<String>();
                
                for (Competitor_Location__c c : competitors) {
                    if (c.Category__c == 'Direct Competitor') ca.directCompetitors++;
                    else ca.indirectCompetitors++;
                    if (c.Threat_Level__c == 'High') ca.highThreatCount++;
                    if (c.Estimated_Revenue__c != null) totalRev += c.Estimated_Revenue__c;
                    
                    details.add(c.Brand_Name__c + ' | ' + c.Category__c + ' | ' + 
                        c.Store_Type__c + ' | ' + c.Distance_From_Site_Km__c + 'km | ' +
                        'INR ' + formatCurrency(c.Estimated_Revenue__c) + '/mo | ' +
                        c.Store_Size_SqFt__c + ' sqft | Est. ' + c.Year_Established__c + ' | ' +
                        c.Threat_Level__c + ' threat');
                }
                
                if (!competitors.isEmpty()) {
                    ca.nearestCompetitor = competitors[0].Brand_Name__c;
                    ca.nearestCompetitorDistance = competitors[0].Distance_From_Site_Km__c;
                    ca.avgCompetitorRevenue = (totalRev / competitors.size()).setScale(0);
                }
                ca.totalMarketRevenue = totalRev.setScale(0);
                ca.competitorDetails = String.join(details, '\n');
                
                // Market assessment
                if (ca.highThreatCount >= 3) {
                    ca.marketAssessment = 'Highly Saturated - Consider differentiated positioning or alternative location. ' + 
                        ca.highThreatCount + ' high-threat competitors present.';
                } else if (ca.totalCompetitors >= 5) {
                    ca.marketAssessment = 'Competitive Market - Viable with strong brand proposition and differentiated format. ' +
                        'Total market revenue of INR ' + formatCurrency(ca.totalMarketRevenue) + '/mo indicates strong demand.';
                } else if (ca.totalCompetitors >= 2) {
                    ca.marketAssessment = 'Moderately Competitive - Good opportunity with the right format. ' +
                        'Only ' + ca.directCompetitors + ' direct competitors present.';
                } else {
                    ca.marketAssessment = 'Low Competition - Strong first-mover advantage available. ' +
                        'This is a potential blind spot with significant untapped demand.';
                }
            }
            results.add(ca);
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