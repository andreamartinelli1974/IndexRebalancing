classdef ParallelBBG < handle
    % class ParallelBBG: the purpose of this class is to parallelize the
    % retrieval of Bloomberg information w.r.t. the list of Bloomberg
    % tickers (tickersList) used to initialize objects of this class. The
    % idea is to be able to launch the AA_DashBoard setting the new
    % 'parallelize_BBG' parameters to true(1): when this is the case this
    % class will try to get with a single request all  the information (or most of it),
    % (both static and historical) that presumably will be required to
    % build instances of the assets and other objects needed to form the
    % investment universe. As long as the functionalities of this class
    % will be extended, the calls to Bloomberg from single objects will
    % progressively become less and less frequent, done only when the
    % required information is not stored within an instance of this class.
    
    % ********************************************************************
    % IMPORTANT: KEEP UP TO DATE THE LIST OF 'Constant' PROPERTIES BELOW,
    % i.e. the set of historical and static fields referenced within the
    % classe asset and its subclasses
    % ********************************************************************
    
    properties (Constant)
        % list of fields that will be used to request data to Bloomberg.
        % Ideally this list should reflect the 'needs' of the various asset
        % classes and so the list of Bloomberg fields used within the
        % single asset classes when the parallelize_BBG is set to false(1)
        historical_fields = {'PX_LAST','PX_VOLUME', 'EQY_FREE_FLOAT_PCT', 'EQY_SH_OUT'};
            % 'EQY_DVD_YLD_EST','EQY_DVD_YLD_IND', ...
            % 'ROLL_ADJUSTED_MID_PRICE','FUT_CUR_GEN_TICKER','CALL_IMP_VOL_30D', ...
            % 'PUT_IMP_VOL_30D','3MO_CALL_IMP_VOL','6MO_CALL_IMP_VOL','12MO_CALL_IMP_VOL', ...
            % '18MO_CALL_IMP_VOL','24MO_CALL_IMP_VOL', '3MO_PUT_IMP_VOL','6MO_PUT_IMP_VOL', ...
            % '12MO_PUT_IMP_VOL', '18MO_PUT_IMP_VOL','24MO_PUT_IMP_VOL'};

        static_fields = {'NAME','EQY_SH_OUT_REAL','COUNTRY'};
            % 'LAST_PRICE','PX_LAST','ID_ISIN','SECURITY_TYP','NAME','CRNCY', ...
            % 'OPT_CONT_SIZE','OPT_TICK_VAL','OPT_VAL_PT','FUT_VAL_PT',...
            % 'FUT_NOMINAL_CONTRACT_VALUE','FUT_TICK_VAL','COUNTRY','INDUSTRY_SECTOR','INDUSTRY_GROUP',...
            % 'TICKER','TICKER_AND_EXCH_CODE','EQY_PRIM_EXCH_SHRT','CUR_MKT_CAP','PE_RATIO', ...
            % 'EBITDA','BEST_ROE_MEDIAN','TOT_DEBT_TO_TOT_CAP','EQY_RAW_BETA','IDX_EST_DVD_YLD', ...
            % 'EQY_DVD_YLD_EST','EQY_DVD_CASH_GROSS_NEXT','BDVD_PROJ_DIV_AMT', ...
            % 'EQY_DVD_CASH_EX_DT_NEXT','BDVD_NEXT_EST_EX_DT','REL_INDEX','TICKER_AND_EXCH_CODE','DUR_MID','DUR_ADJ_MID',...
            % 'CDS_COMPANY_NAME', 'CDS_FIRST_ACCRUAL_START_DATE','CDS_NEXT_LAST_CPN_DATE', ...
            % 'SW_PAY_NOTL_AMT','SW_PAY_FREQ','SW_REC_FREQ','CDS_TERM','CDS_RR', ...
            % 'GENERIC_CDS_INDEX','CDS_PAY_ACCRUED','GENERIC_CDS_INDEX','SW_PAY_NXT_CPN_DT', ...
            % 'OPT_DIV_YIELD','OPT_STRIKE_PX','DELTA_MID_RT','IVOL_MID_RT','OPT_EXPIRE_DT','OPT_DAYS_EXPIRE', ...
            % 'OPT_TICK_VAL','OPT_CONT_SIZE','OPT_TICK_SIZE','OPT_PUT_CALL','OPT_UNDL_TICKER','OPT_EXER_TYP', ...
            % 'IVOL_SURFACE_MONEYNESS','BETA_OVERRIDE_REL_INDEX','MATURITY','PCT_MONEYNESS','UNDL_SPOT_TICKER','DY577', ...
            % 'BASE_CRNCY'};
    end
    
    properties (SetAccess = immutable)
        Parameters; % see below
        DataFromBBG; 
    end
    
    properties (SetAccess = protected)
        TickersList; % list of tickers 'attached' to the object
        Data; % Bloomberg data stored within the object
    end
    
    properties
    end
    
    methods
        function B = ParallelBBG(bbgObj,tickersList,params) 
            % inputs:
            % -> bbgObj: Bloomberg object used to connect to BBG
            % -> tickersList: list of Bloomberg tickers that will be used
            % to get historical or static data from Bloomberg, for fields
            % stored within the constant properties
            % historical_fields/static_fields 
            % -> params: struct array with main sub-fields
            %    .hist: parameters used to download historical data, with
            %    subfields:
            %       .startDate: initial historical data used for all  timeseries
            %       .endDate: final historical data used for all  timeseries
            %       .granularity: granularity of hist data (e.g. 'DAILY')
            %    .static: parameters used to download static data
            B.TickersList = tickersList;
            B.Parameters = params;
            B.DataFromBBG = bbgObj;
        end % ParallelBBG constructor
        
        function GetHistoricalData(B)
            disp('Simultaneous download of BBG historical data (class ParallelBBG)');
            % using method GetHistPrices of class Utilities to
            % simultanously request historical data for the tickers in 'B.TickersList'
            uparams.DataFromBBG = B.DataFromBBG;
            uparams.fields = B.historical_fields;
            uparams.history_start_date = B.Parameters.hist.startDate;
            uparams.history_end_date = B.Parameters.hist.endDate;
            uparams.granularity = B.Parameters.hist.granularity;
            
            % extraction of the two groups of tickers (with
            % and without FX Exposure);
            
            % get the tickers with FXE = 1, exclude the futures from the list and
            % extract the data from bbg
            if iscell(B.TickersList.Var2)
               a = find(cellfun(@isempty,B.TickersList.Var2));
               B.TickersList.Var2{a} = 0;
               B.TickersList.Var2 = cell2mat(B.TickersList.Var2);
            end
            B.TickersList.Var2(isnan(B.TickersList.Var2)) = 0;
            idxFX = find(B.TickersList.Var2);
            idxFX_exFUT = find(~B.TickersList.Var3(idxFX,1));
            tkList = B.TickersList.Var1(idxFX,1);
            tkListFX = tkList(idxFX_exFUT,1);
            
            uparams.ticker = tkListFX';
            uparams.currency = 'EUR';
            
            if ~isempty(idxFX_exFUT)
            U = Utilities(uparams);
            U.GetHistPrices;
            
            HistoricalFX = U.Output.HistInfo;
            else
                HistoricalFX = [];
            end
            
            % get the tickers with FXE = 0, the futures 
            % and extract the data from bbg
            idxNOFX = find(~B.TickersList.Var2);
            idx_FUT = find(B.TickersList.Var3);
            idxNOFX = unique([idxNOFX;idx_FUT]);
            tkListNOFX = B.TickersList.Var1(idxNOFX,1);

            uparams.ticker = tkListNOFX';
            uparams.currency = [];
            
            if ~isempty(idxNOFX)
                U = Utilities(uparams);
                U.GetHistPrices;
                
                HistoricalNOFX = U.Output.HistInfo;
            else
                HistoricalNOFX = [];
            end
            
            % merge the extracted data
            HistInfo = [HistoricalFX;HistoricalNOFX];
            B.TickersList.Var1 = [tkListFX;tkListNOFX];
            B.TickersList.Var2(1:numel(idxFX),1) = 1;
            B.TickersList.Var2(numel(idxFX)+1:end,1) = 0;
            
            n = numel(B.TickersList.Var1);
            nf = numel(B.historical_fields);
            
            for k=1:n % loop over assets
                % when not all the timeseries are numeric, data are
                % saved within a cell array. Need to understand the data
                % type and define 'formatType'
                if isempty(HistInfo{k}) % if there is no data for the securities
                    dates_vector = [];
                else
%                     try
                    dates_vector = HistInfo{k}(:,1); % columns of dates in the final output
%                     catch ggg
%                        disp('check'); 
%                     end
                end
                
                if iscell(dates_vector)
                    formatType = 'cell';
                    dates_vector = cell2mat(dates_vector);
                elseif ~iscell(dates_vector)
                    formatType = 'num';
                else
                    formatType = []; % this should generated an error in the sequel (not managed TODO)
                end
                
                % need to use a prefix ('ticker') to avoid errors when
                % the ticker starts with a number (for example '8306 JT
                % Equity')
                adj_ticker = strrep(B.TickersList.Var1{k},' ','_'); % removing '_' to get string that can be used as field names
                adj_ticker = strrep(adj_ticker,'/','_'); % removing '/'
                adj_ticker = strrep(adj_ticker,'.','_'); % removing '.'
                adj_ticker = strrep(adj_ticker,'(','_'); % removing '('
                adj_ticker = strrep(adj_ticker,')','_'); % removing ')'
                adj_ticker = strrep(adj_ticker,'-','_');
                adj_ticker = strrep(adj_ticker,'=','_');
                
                if B.TickersList.Var2(k) == 1;
                    tkrname = ['ticker_',adj_ticker,'_FXE'];
                else
                    tkrname = ['ticker_',adj_ticker];
                end
                
                B.Data.Historical.(tkrname).dates = dates_vector;
                
                for f=1:nf % loop over BBG fields
                    
                    hist_filed_name = ['bbgField_',B.historical_fields{f}]; % name of the field used in the struct below
                    
                    % reminder: 1st column of HistInfo contanes
                    % the vector ofc historical dates
                    if isempty(HistInfo{k}) % if there is no data for the securities
                        data_vector = [];
                    else
                        data_vector = HistInfo{k}(:,f+1);
                    end
                    
                    % when not all the timeseries are numeric, data are
                    % saved within a cell array. In this case I transform
                    % them back into numeric format, unless it was not
                    % possible due to the nature (non numeric) of the data
                    % (try-catch below)
                    data_vector_type = {};
                    for z = 1:numel(data_vector)
                        try
                            if iscell(data_vector)
                                data_vector_type{z} = class(data_vector{z});
                            else
                                data_vector_type{z} = class(data_vector(z));
                            end
                        catch AA
                            pause(1);
                        end
                    end
                    data_types = unique(data_vector_type);
                    if ~isempty(HistInfo{k}) && ~iscell(HistInfo{k}(:,1))
                        % * nonNaN = find(~isnan(data_vector)); % to remove NaNs
                    elseif ~isempty(HistInfo{k}) && iscell(HistInfo{k}(:,1))
                        
                        if  strcmp(data_types{1},'char') && numel(data_types)==1
                            B.Data.Historical.(tkrname).(hist_filed_name) = data_vector; 
                        else
                            try
                                data_vector = cell2mat(data_vector);
                                % ** nonNaN = find(~isnan(data_vector)); % to remove NaNs
                                
                            catch MM
                                % if it cannot be easily converted into a
                                % numeric array it is probably due to the
                                % nature of data (e.g. a list of tickers, that
                                % is not numeric). In this case I leave the vector as it is.
                                if strcmp(MM.identifier,'MATLAB:cell2mat:MixedDataTypes') ...
                                        | strcmp(MM.identifier,'MATLAB:catenate:dimensionMismatch')
                                    % ** nonNaN = cellfun(@isnan,data_vector,'UniformOutput',0);
                                    % ** nonNaN = ~cell2mat(cellfun(@(x)sum(x)>0,nonNaN,'UniformOutput',0));
                                    B.Data.Historical.(tkrname).(hist_filed_name) = data_vector(:,1);
                                    continue;
                                else
                                    rethrow(MM);
                                end
                            end
                        end
                    end
                    
                    % this is executed only if the vector of data is
                    % numeric
                    if ~isempty(HistInfo{k})
                        B.Data.Historical.(tkrname).(hist_filed_name) =  data_vector(:,1);
                        
                    else
                         B.Data.Historical.(tkrname).(hist_filed_name) = [];
                    end
                    
                end % #f (fields)
                
            end % #n tickers
            
        end % method GetHistoricalData
        
        function GetStaticData(B)
            disp('Simultaneous download of BBG static data (class ParallelBBG)');
            uparams.DataFromBBG = B.DataFromBBG;
            uparams.ticker = B.TickersList.Var1';
            uparams.fields = B.static_fields;
            uparams.override_fields = [];
            
            U = Utilities(uparams);
            U.GetBBG_StaticData;
            
            n = numel(B.TickersList.Var1);
            nf = numel(B.static_fields);
            
            for k=1:n % loop over assets
                % need to use a prefix ('ticker') to avoid errors when
                % the ticker starts with a number (for example '8306 JT
                % Equity')
              
                adj_ticker = strrep(B.TickersList.Var1{k},' ','_'); % removing '_' to get string that can be used as field names
                adj_ticker = strrep(adj_ticker,'/','_'); % removing '/'
                adj_ticker = strrep(adj_ticker,'.','_'); % removing '.'
                adj_ticker = strrep(adj_ticker,'(','_'); % removing '('
                adj_ticker = strrep(adj_ticker,')','_'); % removing ')'
                adj_ticker = strrep(adj_ticker,'-','_'); % removing '-'
                adj_ticker = strrep(adj_ticker,'=','_'); % removing '='
                
                if B.TickersList.Var2(k) == 1;
                    tkrname = ['ticker_',adj_ticker,'_FXE'];
                else
                    tkrname = ['ticker_',adj_ticker];
                end
                
                for f=1:nf % loop over BBG fields
                    B.Data.Static.(tkrname).(B.static_fields{f}) = ...
                        U.Output.BBG_getdata.(B.static_fields{f})(k);
                end
                B.Data.Static.(tkrname).CalledTicker = B.TickersList.Var1{k};
            end
        end % method GetStaticData
        
    end % public methods
end % class definition

