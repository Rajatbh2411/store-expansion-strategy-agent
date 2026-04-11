/**
 * GetSiteScorecard
 * Agentforce Action: Generates a detailed scorecard for a specific location.
 * Topic: Location Recommendation / WhatsApp Query
 */
public with sharing class GetSiteScorecard {

    public class ScorecardRequest {
        @InvocableVariable(label='Site Name or Address' description='Name of the expansion site, micro-market name, or address to look up' required=false)
        public String siteNameOrAddress;
        
        @InvocableVariable(label='PIN Code' description='PIN code to look up the site' required=false)
        public String pinCode;
        
        @InvocableVariable(label='Latitude' description='GPS latitude from field surveyor' required=false)
        public Decimal latitude;
        
        @InvocableVariable(label='Longitude' description='GPS longitude from field surveyor' required=false)
        public Decimal longitude;
        
        @InvocableVariable(label='Request Channel' description='Channel: WhatsApp, Dashboard, Agentforce Chat, API' required=false)
        public String channel;
    }
    
    public class ScorecardResponse {
        @InvocableVariable public String siteName;
        @InvocableVariable public String microMarket;
        @InvocableVariable public String address;
        @InvocableVariable public String pinCode;
        @InvocableVariable public Decimal demandScore;
        @InvocableVariable public String competitionLevel;
        @InvocableVariable public Decimal competitionScore;
        @InvocableVariable public Decimal overallScore;
        @InvocableVariable public Decimal projectedMonthlyRevenue;
        @InvocableVariable public Decimal projectedSetupCost;
        @InvocableVariable public Decimal paybackPeriod;
        @InvocableVariable public Integer competitorCount;
        @InvocableVariable public String recommendation;
        @InvocableVariable public String summary;
        @InvocableVariable public String topCompetitors;
        @InvocableVariable public Boolean isBlindSpot;
        @InvocableVariable public String scorecardId;
        @InvocableVariable public Boolean found;
    }
    
    @InvocableMethod(label='Get Site Scorecard' description='Generates a detailed site scorecard for a specific location. Accepts site name, PIN code, or GPS coordinates. Use when a field surveyor or planner asks about a specific location or sends a GPS pin via WhatsApp.')
    public static List<ScorecardResponse> execute(List<ScorecardRequest> requests) {
        List<ScorecardResponse> responses = new List<ScorecardResponse>();
        
        for (ScorecardRequest req : requests) {
            ScorecardResponse resp = new ScorecardResponse();
            resp.found = false;
            
            Expansion_Site__c site = findSite(req);
            
            if (site != null) {
                resp.found = true;
                resp.siteName = site.Name;
                resp.microMarket = site.Micro_Market__c;
                resp.address = site.Address__c;
                resp.pinCode = site.PIN_Code__c;
                resp.demandScore = site.Demand_Score__c;
                resp.competitionLevel = site.Competition_Level__c;
                resp.competitionScore = site.Competition_Score__c;
                resp.overallScore = (site.Demand_Score__c * 0.6) + ((100 - (site.Competition_Score__c != null ? site.Competition_Score__c : 0)) * 0.4);
                resp.projectedMonthlyRevenue = site.Estimated_Monthly_Revenue__c;
                resp.projectedSetupCost = site.Estimated_Setup_Cost__c;
                resp.paybackPeriod = site.Payback_Period_Years__c;
                resp.competitorCount = (site.Competitor_Count__c != null) ? site.Competitor_Count__c.intValue() : 0;
                resp.recommendation = site.Agent_Recommendation__c;
                resp.isBlindSpot = (site.Demand_Score__c >= 75 && site.Competition_Level__c == 'Low');
                
                // Get top competitors
                List<String> compNames = new List<String>();
                for (Competitor_Location__c c : [
                    SELECT Brand_Name__c, Distance_From_Site_Km__c, Threat_Level__c 
                    FROM Competitor_Location__c 
                    WHERE Expansion_Site__c = :site.Id 
                    ORDER BY Distance_From_Site_Km__c ASC LIMIT 5
                ]) {
                    compNames.add(c.Brand_Name__c + ' (' + c.Distance_From_Site_Km__c + 'km, ' + c.Threat_Level__c + ' threat)');
                }
                resp.topCompetitors = String.join(compNames, '; ');
                
                // Build summary
                String blindSpotTag = resp.isBlindSpot ? 'BLIND SPOT OPPORTUNITY: High demand with low competition. ' : '';
                resp.summary = blindSpotTag +
                    'Site: ' + site.Name + ' | ' +
                    'Demand Score: ' + site.Demand_Score__c + '/100 | ' +
                    'Competition: ' + site.Competition_Level__c + ' (' + compNames.size() + ' competitors within 2km) | ' +
                    'Projected Monthly Revenue: INR ' + formatCurrency(site.Estimated_Monthly_Revenue__c) + ' | ' +
                    'Setup Cost: INR ' + formatCurrency(site.Estimated_Setup_Cost__c) + ' | ' +
                    'Payback Period: ' + site.Payback_Period_Years__c + ' years';
                
                // Create scorecard record
                Site_Scorecard__c sc = new Site_Scorecard__c(
                    Expansion_Site__c = site.Id,
                    Demand_Score__c = site.Demand_Score__c,
                    Competition_Level__c = site.Competition_Level__c,
                    Competition_Score__c = site.Competition_Score__c,
                    Overall_Score__c = resp.overallScore,
                    Projected_Monthly_Revenue__c = site.Estimated_Monthly_Revenue__c,
                    Projected_Setup_Cost__c = site.Estimated_Setup_Cost__c,
                    Payback_Period__c = site.Payback_Period_Years__c,
                    Competitor_Count__c = site.Competitor_Count__c,
                    Summary__c = resp.summary,
                    Request_Channel__c = String.isNotBlank(req.channel) ? req.channel : 'Agentforce Chat',
                    Recommendation__c = getRecommendationCategory(resp.overallScore),
                    Surveyor_GPS_Lat__c = req.latitude,
                    Surveyor_GPS_Long__c = req.longitude
                );
                insert sc;
                resp.scorecardId = sc.Name;
            }
            responses.add(resp);
        }
        return responses;
    }
    
    private static Expansion_Site__c findSite(ScorecardRequest req) {
        String fields = 'Id, Name, Micro_Market__c, Address__c, City__c, PIN_Code__c, ' +
            'Demand_Score__c, Competition_Level__c, Competition_Score__c, ' +
            'Estimated_Monthly_Revenue__c, Estimated_Setup_Cost__c, Payback_Period_Years__c, ' +
            'Competitor_Count__c, Agent_Recommendation__c, Latitude__c, Longitude__c';
        
        // Try by PIN code
        if (String.isNotBlank(req.pinCode)) {
            List<Expansion_Site__c> sites = Database.query(
                'SELECT ' + fields + ' FROM Expansion_Site__c WHERE PIN_Code__c = \'' + 
                String.escapeSingleQuotes(req.pinCode) + '\' ORDER BY Demand_Score__c DESC LIMIT 1'
            );
            if (!sites.isEmpty()) return sites[0];
        }
        
        // Try by name/address search
        if (String.isNotBlank(req.siteNameOrAddress)) {
            String searchTerm = '%' + String.escapeSingleQuotes(req.siteNameOrAddress) + '%';
            List<Expansion_Site__c> sites = Database.query(
                'SELECT ' + fields + ' FROM Expansion_Site__c WHERE (Name LIKE \'' + searchTerm + 
                '\' OR Micro_Market__c LIKE \'' + searchTerm + '\' OR Address__c LIKE \'' + searchTerm + 
                '\') ORDER BY Demand_Score__c DESC LIMIT 1'
            );
            if (!sites.isEmpty()) return sites[0];
        }
        
        // Try by GPS proximity (nearest within 3km)
        if (req.latitude != null && req.longitude != null) {
            List<Expansion_Site__c> allSites = Database.query(
                'SELECT ' + fields + ' FROM Expansion_Site__c WHERE Latitude__c != null'
            );
            Expansion_Site__c nearest = null;
            Decimal minDist = 3.0;
            for (Expansion_Site__c s : allSites) {
                Decimal dist = calculateDistance(req.latitude, req.longitude, s.Latitude__c, s.Longitude__c);
                if (dist < minDist) {
                    minDist = dist;
                    nearest = s;
                }
            }
            return nearest;
        }
        return null;
    }
    
    private static Decimal calculateDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        Double r = 6371;
        Double dLat = (Double)(lat2 - lat1) * Math.PI / 180;
        Double dLon = (Double)(lon2 - lon1) * Math.PI / 180;
        Double a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                   Math.cos((Double)lat1 * Math.PI / 180) * Math.cos((Double)lat2 * Math.PI / 180) *
                   Math.sin(dLon/2) * Math.sin(dLon/2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return Decimal.valueOf(r * c);
    }
    
    private static String getRecommendationCategory(Decimal overallScore) {
        if (overallScore >= 75) return 'Strongly Recommended';
        if (overallScore >= 60) return 'Recommended';
        if (overallScore >= 45) return 'Needs Further Analysis';
        return 'Not Recommended';
    }
    
    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0';
        if (amount >= 10000000) return String.valueOf((amount / 10000000).setScale(1)) + ' Cr';
        if (amount >= 100000) return String.valueOf((amount / 100000).setScale(1)) + ' L';
        return String.valueOf(amount.setScale(0));
    }
}