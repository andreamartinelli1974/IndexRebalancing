classdef Universe<handle
    
    properties
        Equities;
        Excluded;
        TickerList;
        HistDataSet;
        minNumData;
        MaxMinGapDate;
        DataForCalc;
    end
    
    methods
        function U = Universe(params)
            % basically collecting the stocks and prepare the historical
            % data lining up the dates.
            U.Equities = params.equities;
            U.minNumData = params.minNumData;
            
            % get all the dates from Equities.HistStockData
            histDataCollection = [];
            excl_cnt = 1;
            cnt = 1;
            U.MaxMinGapDate = table('Size',[numel(U.Equities),6],'VariableTypes',{'string','double','double','double','double','double'});
            U.MaxMinGapDate.Properties.VariableNames = {'Ticker','MinDate','MaxDate','DaysNmb','MaxGap','MaxGapIndex'};
            for i = 1:numel(U.Equities)
               stockData = U.Equities(i).HistStockData;
               if size(stockData,1) < U.minNumData
                   U.Excluded{excl_cnt,1} = U.Equities(i).Ticker;
                   excl_cnt = excl_cnt + 1;
                   continue
               end
               for k = 2:size(stockData,2)
                   collectionName = strcat("hist",num2str(k-1));
                   histDataCollection.(collectionName){cnt,1} = [U.Equities(i).HistStockData(:,1),...
                       U.Equities(i).HistStockData(:,k)];
               end
               U.TickerList{cnt,1} = U.Equities(i).Ticker;
               cnt = cnt + 1;
               U.MaxMinGapDate.Ticker(i) = U.Equities(i).Ticker;
               U.MaxMinGapDate.MinDate(i) = stockData(1,1);
               U.MaxMinGapDate.MaxDate(i) = stockData(end,1);
               U.MaxMinGapDate.DaysNmb(i) = size(stockData,1);
               [U.MaxMinGapDate.MaxGap(i), U.MaxMinGapDate.MaxGapIndex(i)] = max(stockData(2:end,1)-stockData(1:end-1,1));
               test = find(stockData(2:end,1)-stockData(1:end-1,1)>10);
               if ~isempty(test)
                   disp(test);
                   disp(U.Equities(i).Ticker);
               end
            end
            
            for j = 1:size(stockData,2)-1
                setName = strcat("hist",num2str(j));
                uparams.op_type = 'intersect';
                uparams.inputTS = histDataCollection.(setName);
                Util = Utilities(uparams);
                Util.GetCommonDataSet;
                
                U.HistDataSet.(setName).dates = Util.Output.DataSet.dates;
                U.HistDataSet.(setName).data = Util.Output.DataSet.data;
            end
            
        end % end constructor
        
        function ftsemibCalculator(U)
            % this methods is strictly index dependent 
            % U.Equities(i).HistStockData composition:
            % date, Prices, Volumes, FreeFloat, SharesOut
            
            % TODO: INSERT THE LIST OF REBALANCING DATA (END OF ANY PERIOD)
            % TODO: INSERT THE FREEFLOAT CALCULATION RULE: THE FF IS FIXED
            % DURING THE QUARTER AND EVENTUALLY UPDATED SUBJECT TO SOME
            % LIMITATIONS
            % TODO: INSERT THE OUTSTANDING SHARES CALCULATION RULE: THE
            % NUMBER OF OS IS FIXED DURING THE QUARTER AND EVENTUALLY
            % UPDATED SUBJECT TO SOME LIMITATIONS
            
            for i = 1:numel(U.Equities)
                % set the end date for the period (2 quarters)
                % TODO: INSERT A CHECK FOR NEW ISSUES AND TRACKS SHORTER
                % THAN 2 QUARTERS
                stockData = U.Equities(i).HistStockData;
                fd = find(stockData(:,1)<=datemnth(stockData(1,1),6)+1);
                firstMonth = fd(end);
                enddate = stockData(firstMonth,1);
                j = 0;
                % 1) calculate the average of daily official prices of the last
                % month
                while firstMonth+j<size(stockData,1)
                    startdate = datemnth(enddate,-1)+1;
                    firstDateIdx = find(stockData(:,1)==startdate);
                    if isempty(firstDateIdx)
                        firstDateIdx = max(find(stockData(:,1)<=startdate));
                        if startdate-stockData(firstDateIdx,1)>6
                            disp(strcat(U.Equities(i).Ticker," - issues on data: ", num2str(firstMonth+j)));
                        end
                    end
                    priceToSum = stockData(firstDateIdx:firstMonth+j,2);
                    j = j+1;
                    avgPriceMonth(j,1) = enddate;
                    avgPriceMonth(j,2) = sum(priceToSum)/numel(priceToSum);
                    enddate = stockData(firstMonth+j,1);
                end
                U.DataForCalc.AvgPriceMonth{i,1} = avgPriceMonth;
                
                % 2) calculate Turnover over last two quarter as sum of
                % daily volume * last price
                firstMonth = fd(end);
                enddate = stockData(firstMonth,1);
                j = 0;
                while firstMonth+j<size(stockData,1)
                    startdate = datemnth(enddate,-6)+1;
                    firstDateIdx = find(stockData(:,1)==startdate);
                    if isempty(firstDateIdx)
                        firstDateIdx = max(find(stockData(:,1)<=startdate));
                        if startdate-stockData(firstDateIdx,1)>6
                            disp(strcat(U.Equities(i).Ticker," - issues on data: ", num2str(firstMonth+j)));
                        end
                    end
                    priceToUse = stockData(firstDateIdx:firstMonth+j,2);
                    volumeToUse = stockData(firstDateIdx:firstMonth+j,3);
                    j = j+1;
                    turnover(j,1) = enddate;
                    turnover(j,2) = sum(priceToUse.*volumeToUse);
                    listingDays(j,1) = enddate;
                    listingDays(j,2) = numel(priceToUse);
                    enddate = stockData(firstMonth+j,1);
                end
                U.DataForCalc.Turnover{i,1} = turnover;
                U.DataForCalc.ListingDays{i,1} = listingDays;
                
                % 3) compute the adjusted market cap:
                % adjMktCap = SharesInIssue * FreeFloat * avgPriceMonth
                % and absolute market cap:
                % absMktCap = SharesInIssue * avgPriceMonth
                firstMonth = fd(end);
                enddate = stockData(firstMonth,1);
                j = 0;
                while firstMonth+j<size(stockData,1)
                    %%% TO BE MODIFIED WHEN USING SHARE RULE & FREEFLOAT RULE %%
                    shares = stockData(firstMonth+j,5)*10e6;
                    ff = stockData(firstMonth+j,4);
                    j = j+1;
                    SharesInIssue(j,1) = enddate;
                    SharesInIssue(j,2) = shares;
                    FreeFloat(j,1) = enddate;
                    FreeFloat(j,2) = ff/100;
                    enddate = stockData(firstMonth+j,1);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                end
                avgPrice = U.DataForCalc.AvgPriceMonth{i,1};
                adjMktCap(:,1) = avgPrice(:,1);
                adjMktCap(:,2) = SharesInIssue(:,2).*FreeFloat(:,2).* avgPrice(:,2);
                U.DataForCalc.AdjMktCap{i,1} = adjMktCap;
                absMktCap(:,1) = avgPrice(:,1);
                absMktCap(:,2) = SharesInIssue(:,2).* avgPrice(:,2);
                U.DataForCalc.ABS_MktCap{i,1} = absMktCap;
                
                % 4) compute the Alpha: AdjMktCap/Turnover/ListingDays
                trnov =  U.DataForCalc.Turnover{i,1};
                lstdays =  U.DataForCalc.ListingDays{i,1};
                alpha(:,1) = adjMktCap(:,1);
                alpha(:,2) = adjMktCap(:,2)./trnov(:,2)./lstdays(:,2);
                U.DataForCalc.Alpha{i,1} = alpha;
                
            end % end of 'for any stock'
            
            % 5) compute the IndLiqAdjCap:
            % AdjMktCap + (AlphaMKT * Turnover/ListingDays)
            % where AlphaMKT = Sum(AdjMktCap)/Sum(Turnover/ListingDays)
            
            % compute AlphaMKT
            for i = 1:numel(U.DataForCalc.AdjMktCap)
                sumAdjMktCap = 0;
                sumTvLst = 0;
                adjMktCap = U.DataForCalc.AdjMktCap{i,1};
                sumAdjMktCap = sumAdjMktCap + adjMktCap(:,2);
                
                trnov =  U.DataForCalc.Turnover{i,1};
                lstdays =  U.DataForCalc.ListingDays{i,1};
                sumTvLst = sumTvLst + trnov(:,2)./lstdays(:,2);
            end
            
            alphaMKT(:,1) = adjMktCap(:,1);
            alphaMKT(:,2) = sumAdjMktCap./sumTvLst;
            U.DataForCalc.AlphaMKT = alphaMKT;
            
            % compute IndLiqAdjCap
            for i = 1:numel(U.DataForCalc.AdjMktCap)
                % AdjMktCap + (AlphaMKT * Turnover/ListingDays)
                adjMktCap = U.DataForCalc.AdjMktCap{i,1};
                trnov =  U.DataForCalc.Turnover{i,1};
                lstdays =  U.DataForCalc.ListingDays{i,1};
                
                indLiqAdjCap(:,1) = adjMktCap(:,1);
                indLiqAdjCap(:,2) = adjMktCap(:,2)+(alphaMKT(:,2).*(trnov(:,2)./lstdays(:,2)));
                U.DataForCalc.IndLiqAdjCap{i,1} = indLiqAdjCap;
            end
            
            %%%% ****** CALCULATION OF THE TABLE RANKING ****** %%%%
            
            % TODO: insert filters on Alpha, Super Liquidity filter and
            % others filters as per the FTSE Russel rules.
            
            % create the table to be ranked (one table for any day)
            
            
            for k = 1:numel(U.Equities)
                abs_mkt_cap = U.DataForCalc.ABS_MktCap{k,1};
                dates = abs_mkt_cap(:,1);
                indLiqAdjCap = U.DataForCalc.IndLiqAdjCap{k,1};
                SingleEquityRanking{k,1} = table(dates, abs_mkt_cap(:,2), indLiqAdjCap(:,2));
            end
            
            dates = U.DataForCalc.AlphaMKT(:,1);
            for i = 1:numel(dates)
                disp(datestr(dates(i)));
                for k = 1:numel(U.Equities)
                    equityName = U.Equities(k).Ticker;
                    singleEquityRank = SingleEquityRanking{k,1};
                    if k == 1
                        SingleDateRanking{i,1} = table({equityName},singleEquityRank{i,1},...
                            singleEquityRank{i,2},singleEquityRank{i,3});
                    else
                        newRow = table({equityName},singleEquityRank{i,1},...
                            singleEquityRank{i,2},singleEquityRank{i,3});
                        SingleDateRanking{i,1} = [SingleDateRanking{i,1};newRow];
                    end
                end
                SingleDateRanking{i,1}.Properties.VariableNames = ["Ticker","Date","AbsMktCap","IndLiqAdjCap"];
                SingleDateRanking{i,1} = sortrows(SingleDateRanking{i,1},3,'descend');
                RankingTable{i,1} = SingleDateRanking{i,1}(1:100,:);
                RankingTable{i,1} = sortrows( RankingTable{i,1},4,'descend');
            end
            U.DataForCalc.SingleDateRanking = SingleDateRanking;
            U.DataForCalc.RankingTable = RankingTable;
            U.DataForCalc.dates = dates;
        end
        
        function IndexForecast(U,lag)
            % this is the method use to forecast the index composition
            % "lag" number of days before the announcement
            % it must be as index independent as possible 
            
        end
    end
    
end