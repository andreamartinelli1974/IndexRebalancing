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
            for i = 1:numel(U.Equities)
                % 1) calculate the average of daily official prices of the last
                % month
                stockData = U.Equities(i).HistStockData;
                fd = find(stockData(:,1)<=datemnth(stockData(1,1),1));
                firstMonth = fd(end);
                enddate = stockData(firstMonth,1);
                j = 0;
                firstDateIdx = 1;
                while firstMonth+j<size(stockData,1)
                    priceToSume = stockData(firstDateIdx:firstMonth+j,2);  
                    j = j+1;
                    avgPriceMonth(j,1) = enddate;
                    avgPriceMonth(j,2) = sum(priceToSume)/numel(priceToSume);
                    enddate = stockData(firstMonth+j,1);
                    startdate = datemnth(enddate,-1);
                    firstDateIdx = find(stockData(:,1)==startdate);
                    if isempty(firstDateIdx)
                        firstDateIdx = max(find(stockData(:,1)<=startdate));
                        if startdate-stockData(firstDateIdx,1)>6
                            disp(strcat(U.Equities(i).Ticker," - issues on data: ", num2str(firstMonth+j)));
                        end
                    end
                end
                U.DataForCalc.Price{i,1} = avgPriceMonth;
                
                % 2) calculate Turnover over last two quarter as sum of
                % daily volume * last price
            end
            
        end
        
        function IndexForecast(U,lag)
            % this is the method use to forecast the index composition
            % "lag" number of days before the announcement
            % it must be as index independent as possible 
            
        end
    end
    
end