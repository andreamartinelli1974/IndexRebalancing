classdef Universe<handle
    
    properties
        Equities;
        Excluded;
        TickerList;
        HistDataSet;
        minNumData;
        
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
        end
        
        function IndexForecast(U,lag)
            % this is the method use to forecast the index composition
            % "lag" number of days before the announcement
            % it must be as index independent as possible 
            
        end
    end
    
end