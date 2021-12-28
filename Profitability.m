% PROFITABILITY TEST %
% using the past index in/out and different time horizon for in and out for
% the trade, we ty to figure out the profitability of the strategy
% WE ARE USING ONLY THE ORDINARY QUARTERLY REVIEWS INCLUSIONS AND
% EXCLUSIONS, AND ONLY FOR AVAILABLE BBG TICKERS

clear all;
close all;
clc;

if ~isdeployed
    pt = path;
    userId = getenv('USERNAME');
    if strcmpi(userId,'U370176')
        dsk = 'D:\';
    else
        dsk = 'C:\';
    end
    addpath([dsk,'Users\' userId '\Documents\GitHub\Utilities\']);
end

% **************** STRUCTURE TO ACCESS BLOOMBERG DATA *********************
DataFromBBG.save2disk = false(1); % false(1); % True to save all Bloomberg calls to disk for future retrieval
DataFromBBG.folder = [cd,'\BloombergCallsData\'];

if DataFromBBG.save2disk
    if exist('BloombergCallsData','dir')==7
        rmdir(DataFromBBG.folder(1:end-1),'s');
    end
    mkdir(DataFromBBG.folder(1:end-1));
end

try
    % javaaddpath('C:\blp\DAPI\blpapi3.jar');
    DataFromBBG.BBG_conn = blp; % throw error when Bloomberg is not installed
    pause(2);
    while isempty(DataFromBBG.BBG_conn) % ~isconnection(DataFromBBG.BBG_conn)
        pause(2);
    end
    
    DataFromBBG.NOBBG = false(1); % True when Bloomberg is NOT available and to use previopusly saved data
    
catch ME
    % dlgTitle = 'BBG ALERT';
    % dlgQuest = 'BLOOMBER NOT AVAILABLE! Do you with to continue?';
    % answer = questdlg(dlgQuest,dlgTitle,'yes','no','no');
    % if strcmp(answer,'no')
    %     return
    % end
    if isdeployed
        RunMsg = msgbox('Connection to Bloomberg not available', ...
            'Deployed code execution');
    end
    DataFromBBG.BBG_conn = [];
    DataFromBBG.NOBBG = true(1); % if true (on machines with no BBG terminal), data are recovered from previously saved files (.save2disk option above)
end

%% Input Session
PreviousLag = 60; % calendar
BDayCompensator = round(60/1.5,0);
PosteriorLag = 14; % calendar
InvestedAmount = 100000;

ReviewTable = readtable('Rebalancing.xlsx');

mindate = min(ReviewTable.dataDiCalcolo);
mindate = busdate(mindate-PreviousLag-BDayCompensator,-1);

tickersList = unique([ReviewTable.tkrEscluse; ReviewTable.tkrAmmesse]);
tickersList(find(contains(tickersList,'#na')))=[];


%% create instance of class 'ParallelBBG'
% to parallelize most of the Bloomberg requests presumably needed to build
% objects of class 'asset', IR_Curve, CDS, etc.
BBG_SimultaneousData = [];
% % if false % to exclude parallel download from BBG

input_params.history_start_date = mindate;
input_params.history_end_date = datestr(today-1,'mm/dd/yyyy');
input_params.granularity = "DAILY";

if ~DataFromBBG.save2disk & ~DataFromBBG.NOBBG % CANNOT BE USED WHEN USING THE 'save to disk feature' or the NOBBG one
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    THIS IS INDEX SPECIFIC: INDEX TICKER USED TO GET TRADING DAYS    %
    tickersList{end+1} = "FTSEMIB Index";
    %                                                                     %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    zeroColumn = repmat({zeros(1)},size(tickersList)); %% just to use parallelBBG.
    tickersListFXe = cell2table([tickersList,zeroColumn,zeroColumn]);
    
    parallelBBG_params.hist.startDate = input_params.history_start_date;
    parallelBBG_params.hist.endDate = input_params.history_end_date;
    parallelBBG_params.hist.granularity = input_params.granularity;
    
    if true(1) % false(1) ** to include/exclude simultaneous download
        BBG_SimultaneousData = ParallelBBG(DataFromBBG,tickersListFXe,parallelBBG_params);
        BBG_SimultaneousData.GetHistoricalData;
        BBG_SimultaneousData.GetStaticData;
    end
    
end

%% create the TradingDays list from index & calculate nonTradingDays as difference
adj_ticker = strrep("FTSEMIB Index",' ','_'); % removing '_' to get string that can be used as field names
    adj_ticker = strrep(adj_ticker,'/','_'); % removing '/'
    adj_ticker = strrep(adj_ticker,'.','_'); % removing '.'
    adj_ticker = strrep(adj_ticker,'(','_'); % removing '('
    adj_ticker = strrep(adj_ticker,')','_'); % removing ')'
    adj_ticker = strrep(adj_ticker,'-','_');
    adj_ticker = strrep(adj_ticker,'=','_');
    
tkrname = strcat('ticker_',adj_ticker);
   
TradingDays = BBG_SimultaneousData.Data.Historical.(tkrname).dates;
allDate = (TradingDays(1):1:TradingDays(end));
nonTradingDays = setdiff(allDate,TradingDays)';

%% create and fill all the equities objects

e_cnt = 0;
exept_cnt = 0;
for i = 1:numel(tickersListFXe.Var1)-1
    ticker = tickersListFXe.Var1{i};
    % set shares number = 0 (is usless in this exercise)
    shares = 0;
    % generate ticker name used in ParallelBBG
    adj_ticker = strrep(ticker,' ','_'); % removing '_' to get string that can be used as field names
    adj_ticker = strrep(adj_ticker,'/','_'); % removing '/'
    adj_ticker = strrep(adj_ticker,'.','_'); % removing '.'
    adj_ticker = strrep(adj_ticker,'(','_'); % removing '('
    adj_ticker = strrep(adj_ticker,')','_'); % removing ')'
    adj_ticker = strrep(adj_ticker,'-','_');
    adj_ticker = strrep(adj_ticker,'=','_');
    
    if tickersListFXe.Var2(i) == 1;
        tkrname = ['ticker_',adj_ticker,'_FXE'];
    else
        tkrname = ['ticker_',adj_ticker];
    end
    
    e_params.ticker = tkrname; 
    e_params.holidays = [];
    e_params.nonTradingDays = nonTradingDays; 
    e_params.tradingDays = TradingDays;
    e_params.bbg_data = BBG_SimultaneousData;
    e_params.shares = shares;
    e_cnt = e_cnt+1;
    try
        E(e_cnt,1) = Equity(e_params);
        tickersList{i,2}=e_cnt;
    catch AM
        disp(["error while creating",e_params.ticker]);
        e_cnt = e_cnt-1;
        exept_cnt = exept_cnt +1;
        exception{exept_cnt} = e_params.ticker;   
    end
end

%% calculating the porfitability

uniqueDate = unique(ReviewTable.dataDiCalcolo);
OutPerf = [];

for i = 1:numel(uniqueDate)
    
    calcDate = uniqueDate(i);
    dateidx = find(ReviewTable.dataDiCalcolo==calcDate);
    reviewDate = ReviewTable.DataEffettiva(dateidx(1));
    
    % calculate the collection of date to start the investment, from
    % calcDate - PreviousLag to calcDate -1
    prevDate = TradingDays(find(TradingDays>=datenum(calcDate-PreviousLag-BDayCompensator)& TradingDays<datenum(calcDate)));
    prevDate = prevDate(end-PreviousLag+1:end,:);
    % calculate the collection of date to stop the investment, from
    % calcDate + 1 to calcDate + PosteriorLag
    postDate = TradingDays(TradingDays>datenum(reviewDate)& TradingDays<=datenum(reviewDate+PosteriorLag+BDayCompensator));
    postDate = postDate(1:PosteriorLag,:);
    
    OutPerf{i} = zeros(numel(prevDate),numel(postDate));
    InPerf{i}  = zeros(numel(prevDate),numel(postDate));
    
    for z = 1:numel(dateidx)
        
        position = dateidx(z);
        % calculate the p&l for any prevDate & postDate combination
        for j=1:numel(prevDate)
            for k = 1:numel(postDate)
                tickerOut = ReviewTable.tkrEscluse(position);
                datePerf{i}{j,k} = {prevDate(j),postDate(k)};
                if ~strcmp(tickerOut,"#na")
                    idxOut = strcmp(tickersList(:,1),tickerOut);
                    stockHistOut = E(idxOut).HistStockData(:,1:2);
                    fdstart = find(stockHistOut(:,1)==prevDate(j));
                    fdend = find(stockHistOut(:,1)==postDate(k));
                    priceStartOut = stockHistOut(fdstart,2);
                    priceEndOut = stockHistOut(fdend,2);
                    if(~isempty(priceEndOut) & ~isempty(priceStartOut))
                        OutPerf{i}(j,k)  = OutPerf{i}(j,k)+ InvestedAmount * log(priceEndOut/priceStartOut);
                    end
                end
                
                tickerIn = ReviewTable.tkrAmmesse(position);
                if ~strcmp(tickerIn,"#na")
                    idxIn = strcmp(tickersList(:,1),tickerIn);
                    stockHistIn = E(idxIn).HistStockData(:,1:2);
                    fdstart = find(stockHistIn(:,1)==prevDate(j));
                    fdend = find(stockHistIn(:,1)==postDate(k));
                    priceStartIn = stockHistIn(fdstart,2);
                    priceEndIn = stockHistIn(fdend,2);
                    if(~isempty(priceEndIn) & ~isempty(priceStartIn))
                        InPerf{i}(j,k)   = InPerf{i}(j,k)  + InvestedAmount * log(priceEndIn/priceStartIn);
                    end
                end
            end
        end
    end
end

%% calculate profit metrics

% sum the OutPer for any Review date and do the same for InPerf
outPerfSize = size(OutPerf{1});
dimensions = [numel(OutPerf),outPerfSize];
OutPerfCube = zeros(dimensions);
InPerfCube = zeros(dimensions);

for i = 1:numel(OutPerf)
    OutPerfCube(i,:,:) = OutPerf{i};
    InPerfCube(i,:,:) = InPerf{i};
end


for k=1:outPerfSize(1)
    for j=1:outPerfSize(2)
        zerocountOut(k,j) = dimensions(1) - sum(OutPerfCube(:,k,j)==0);
        zerocountIn(k,j) = dimensions(1) - sum(InPerfCube(:,k,j)==0);
    end
end

rowtodelete =(zerocountOut(:,1)==0);
coltodelete =(zerocountOut(1,:)==0);
OutPerfCube(:,rowtodelete,:) = [];
OutPerfCube(:,:,coltodelete) = [];
zerocountOut(rowtodelete,:) = [];
zerocountOut(:,coltodelete) = [];
cubeSize = size(OutPerfCube);
aa = sum(OutPerfCube,1);
totOutPerf = reshape(aa,cubeSize(2:3))./zerocountOut;

rowtodelete =(zerocountIn(:,1)==0);
coltodelete =(zerocountIn(1,:)==0);
InPerfCube(:,rowtodelete,:) = [];
InPerfCube(:,:,coltodelete) = [];
zerocountIn(rowtodelete,:) = [];
zerocountIn(:,coltodelete) = [];
cubeSize = size(InPerfCube);
bb = sum(InPerfCube,1);
totInPerf  = reshape(bb,cubeSize(2:3))./zerocountIn;

OutPerfCube(OutPerfCube==0) = NaN;
InPerfCube(InPerfCube==0) = NaN;

for k=1:cubeSize(2)
    for j=1:cubeSize(3)
        maxOut(k,j) = max(OutPerfCube(:,k,j));
        minOut(k,j) = min(OutPerfCube(:,k,j));
        maxIn(k,j) = max(InPerfCube(:,k,j));
        minIn(k,j) = min(InPerfCube(:,k,j));
        Out25(k,j) = prctile(OutPerfCube(:,k,j),25);
        Out75(k,j) = prctile(OutPerfCube(:,k,j),75);
        In25(k,j) = prctile(OutPerfCube(:,k,j),25);
        In75(k,j) = prctile(OutPerfCube(:,k,j),75);
    end
end






