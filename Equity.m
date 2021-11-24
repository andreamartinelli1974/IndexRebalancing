classdef Equity<handle
    
    % class to handle stock info
    % the info stored are basically index dependent so this class
    % composition is influenced by the index rules.
    % actually the goal is to create a table of historical data that could
    % be managed by universe without knowing what kind of data are.
    % only the method used to calculate the index composition must know the
    % data nature
    
    properties (SetAccess = protected)
        Ticker;
        HolidaysDate;
        TradingDays;
        NonTradingDays;
        bbg_data;
        HistStockData;
        StaticStockData;
        SharesFromFTSE;
        % and others to follow
    end
    
    methods
        function E = Equity(params)
            E.Ticker = params.ticker;
            E.HolidaysDate = params.holidays;
            E.TradingDays = params.tradingDays;
            E.NonTradingDays = params.nonTradingDays
            E.SharesFromFTSE = params.shares;
            bbg_data = params.bbg_data;
            E.bbg_data.dates = bbg_data.Data.Historical.(E.Ticker).dates;
            E.bbg_data.PX_LAST = bbg_data.Data.Historical.(E.Ticker).bbgField_PX_LAST;
            E.bbg_data.PX_VOLUME = bbg_data.Data.Historical.(E.Ticker).bbgField_PX_VOLUME;
            E.bbg_data.EQY_FREE_FLOAT_PCT = bbg_data.Data.Historical.(E.Ticker).bbgField_EQY_FREE_FLOAT_PCT; 
            E.bbg_data.EQY_SH_OUT = bbg_data.Data.Historical.(E.Ticker).bbgField_EQY_SH_OUT;
            E.bbg_data.EQT_SH_OUT_REAL = bbg_data.Data.Static.(E.Ticker).EQY_SH_OUT_REAL;
            E.StaticStockData.Name = bbg_data.Data.Static.(E.Ticker).NAME;
            E.StaticStockData.Country = bbg_data.Data.Static.(E.Ticker).COUNTRY;
            E.StaticStockData.Shares = E.bbg_data.EQT_SH_OUT_REAL;

            % calculate and fill al the field ,needed to calculate the index
            % ranking
            
            % create array with all data and removing nan
            % array containing: dates, prices, volumes, freefloat
            E.HistStockData = [E.bbg_data.dates,E.bbg_data.PX_LAST,E.bbg_data.PX_VOLUME,...
                         E.bbg_data.EQY_FREE_FLOAT_PCT,E.bbg_data.EQY_SH_OUT];
            E.HistStockData(any(isnan(E.HistStockData), 2), :) = [];
            
            % check the data
            if size(E.HistStockData,1) == 0
                disp(E.Ticker);
            end
            
            %E.Prices = [stockData(:,1),stockData(:,2)];
            %E.Volumes = [stockData(:,1),stockData(:,3)];
            %E.FreeFloatPct = [stockData(:,1),stockData(:,4)];
            % get the first date to process 
        end % end constructor
    end
end
            
        