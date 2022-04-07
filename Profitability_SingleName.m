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
BDayCompensator = PreviousLag;
PosteriorLag = 5; % calendar
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

OutPerf = [];

for i = 1:numel(ReviewTable.dataDiCalcolo)
    
    calcDate = ReviewTable.dataDiCalcolo(i);
    reviewDate = ReviewTable.DataEffettiva(i);
    %calcDate = reviewDate;
    
    % calculate the collection of date to start the investment, from
    % calcDate - PreviousLag to calcDate -1
    prevDate = TradingDays(find(TradingDays>=datenum(calcDate-PreviousLag-BDayCompensator)& TradingDays<datenum(calcDate)));
    prevDate = prevDate(end-PreviousLag+1:end,:);
    % calculate the collection of date to stop the investment, from
    % calcDate + 1 to calcDate + PosteriorLag
    postDate = TradingDays(TradingDays>datenum(reviewDate)& TradingDays<=datenum(reviewDate+PosteriorLag+BDayCompensator));
    postDate = postDate(1:PosteriorLag,:);
    
    OutPerf{i} = zeros(numel(prevDate)+1,numel(postDate)+1);
    InPerf{i}  = zeros(numel(prevDate)+1,numel(postDate)+1);
    
    OutPerf{i}(1,1) = 1;
    InPerf{i}(1,1) = 1;
    
    PrevDate{i} = OutPerf{i};
    PostDate{i}  = InPerf{i};
    
    
    
    % calculate the p&l for any prevDate & postDate combination
    for j=2:numel(prevDate)+1
        for k = 2:numel(postDate)+1
            tickerOut = ReviewTable.tkrEscluse(i);
            PrevDate{i}(j,k) = prevDate(j-1);
            PostDate{i}(j,k) = postDate(k-1);
            %datePerf{i}{j,k} = {prevDate(j),postDate(k)};
            if ~strcmp(tickerOut,"#na")
                idxOut = strcmp(tickersList(:,1),tickerOut);
                stockHistOut = E(idxOut).HistStockData(:,1:2);
                fdstart = find(stockHistOut(:,1)==prevDate(j-1));
                fdend = find(stockHistOut(:,1)==postDate(k-1));
                priceStartOut = stockHistOut(fdstart,2);
                priceEndOut = stockHistOut(fdend,2);
                if(~isempty(priceEndOut) & ~isempty(priceStartOut))
                    OutPerf{i}(j,k)  = OutPerf{i}(j,k)- InvestedAmount * ((priceEndOut-priceStartOut)/priceStartOut);
                end
            end
            
            OutPerf{i}(j,1)=-(size(prevDate,1)-j+2);
            OutPerf{i}(1,k)=(k-1);
            
            tickerIn = ReviewTable.tkrAmmesse(i);
            if ~strcmp(tickerIn,"#na")
                idxIn = strcmp(tickersList(:,1),tickerIn);
                stockHistIn = E(idxIn).HistStockData(:,1:2);
                fdstart = find(stockHistIn(:,1)==prevDate(j-1));
                fdend = find(stockHistIn(:,1)==postDate(k-1));
                priceStartIn = stockHistIn(fdstart,2);
                priceEndIn = stockHistIn(fdend,2);
                if(~isempty(priceEndIn) & ~isempty(priceStartIn))
                    InPerf{i}(j,k)   = InPerf{i}(j,k)  + InvestedAmount * ((priceEndIn-priceStartIn)/priceStartIn);
                end
            end
            InPerf{i}(j,1)=-(size(prevDate,1)-j+2);
            InPerf{i}(1,k)=(k-1);
        end
    end
    
end

%% calculate profit metrics

% sum the OutPer for any Review date and do the same for InPerf
outPerfSize = size(OutPerf{1});
dimensions = [outPerfSize,numel(OutPerf)];
OutPerfCube = zeros(dimensions);
InPerfCube = zeros(dimensions);
OutPrevDateCube = zeros(dimensions);
InPrevDateCube = zeros(dimensions);
OutPostDateCube = zeros(dimensions);
InPostDateCube = zeros(dimensions);
tkrIn = ReviewTable.tkrAmmesse;
tkrOut = ReviewTable.tkrEscluse;

for i = 1:numel(OutPerf)
    OutPerfCube(:,:,i) = OutPerf{i};
    InPerfCube(:,:,i) = InPerf{i};
    OutPrevDateCube(:,:,i) = PrevDate{i};
    InPrevDateCube(:,:,i) = PrevDate{i};
    OutPostDateCube(:,:,i) = PostDate{i};
    InPostDateCube(:,:,i) = PostDate{i};
end

for kk = 1:dimensions(3)
    checkOut = sum(sum(OutPerfCube(2:end,2:end,kk)));
    if(checkOut ==0)
        OutPageToDelete(kk) = 1;
    else
        OutPageToDelete(kk) = 0;
    end
    checkIn = sum(sum(InPerfCube(2:end,2:end,kk)));
    if(checkIn ==0)
        InPageToDelete(kk) = 1;
    else
        InPageToDelete(kk) = 0;
    end
end

OutPerfCube(:,:,logical(OutPageToDelete))=[];
InPerfCube(:,:,logical(InPageToDelete))=[];

OutPrevDateCube(:,:,logical(OutPageToDelete))=[];
OutPostDateCube(:,:,logical(OutPageToDelete))=[];
InPrevDateCube(:,:,logical(InPageToDelete))=[];
InPostDateCube(:,:,logical(InPageToDelete))=[];

tkrOut(logical(OutPageToDelete))=[];
tkrIn(logical(InPageToDelete))=[];

OutPerfCube(OutPerfCube==0) = NaN;
InPerfCube(InPerfCube==0) = NaN;

OutCubeSize = size(OutPerfCube);
InCubeSize = size(InPerfCube);

for k=1:OutCubeSize(1)
    for j=1:OutCubeSize(2)
        medianOut(k,j) = median(OutPerfCube(k,j,:),'omitnan');
        [maxOut(k,j),maxOutIdx(k,j)] = max(OutPerfCube(k,j,:));
        [minOut(k,j),minOutIdx(k,j)] = min(OutPerfCube(k,j,:));
        Out25(k,j)     = prctile(OutPerfCube(k,j,:),25);
        Out75(k,j)     = prctile(OutPerfCube(k,j,:),75);
    end
end

for k=1:InCubeSize(1)
    for j=1:InCubeSize(2)
        medianIn(k,j)  = median(InPerfCube(k,j,:),'omitnan');
        [maxIn(k,j),maxInIdx(k,j)] = max(InPerfCube(k,j,:));
        [minIn(k,j),minInIdx(k,j)]= min(InPerfCube(k,j,:));
        In25(k,j)      = prctile(InPerfCube(k,j,:),25);
        In75(k,j)      = prctile(InPerfCube(k,j,:),75);
    end
end

%% boxplot
close all

bplotIn  = zeros(size(InPerfCube,3)+1,size(InPerfCube,1)-1);
bplotOut = zeros(size(OutPerfCube,3)+1,size(OutPerfCube,1)-1);
for i = 2:size(medianOut,2)
    
    for k=1:size(medianOut,1)-1
        bplotOut(1,k) = OutPerfCube(k+1,1,1);
        bplotOut(2:end,k)= OutPerfCube(k+1,i,:);
    end
    
    figure 
    boxplot(bplotOut(2:end,:));
    title(strcat("Investment in excluded name: Posterior lag = ", num2str(i-1)));
    xticklabels( bplotOut(1,:));
    xlabel("Business days before the Calc. Date");
    ylabel(strcat("P&L on ",num2str(InvestedAmount)," eur short"));
    ytickformat('eur');
    hline = refline(0, 0);
    hline.Color = 'k';
end
for i = 2:size(medianIn,2)
    
    for k=1:size(medianIn,1)-1
        bplotIn(1,k) = InPerfCube(k+1,1,1);
        bplotIn(2:end,k)= InPerfCube(k+1,i,:);
    end
    figure;
    boxplot(bplotIn(2:end,:));
    title(strcat("Investment in admetted name: Posterior lag = ", num2str(i-1)));
    xticklabels( bplotIn(1,:));
    xlabel("Business days before the Calc. Date");
    ylabel(strcat("P&L on ",num2str(InvestedAmount)," eur long"));
    ytickformat('eur');
    hline = refline(0, 0);
    hline.Color = 'k';
end

%% find outliers (max & min)

[rows, cols] = size(maxInIdx);
for i = 2:rows
    for j = 2:cols
        MaxIn.Names(i-1,j-1)=tkrIn(maxInIdx(i,j));
        MaxIn.PrevDate(i-1,j-1)=InPrevDateCube(i,j,maxInIdx(i,j));
        MaxIn.PostDate(i-1,j-1)=InPostDateCube(i,j,maxInIdx(i,j));
        
        idxIn = strcmp(tickersList(:,1),MaxIn.Names(i-1,j-1));
        stockHist = E(idxIn).HistStockData(:,1:2);
        fdstart = find(stockHist(:,1)==MaxIn.PrevDate(i-1,j-1));
        fdend = find(stockHist(:,1)==MaxIn.PostDate(i-1,j-1));
        MaxIn.priceStart(i-1,j-1) = stockHist(fdstart,2);
        MaxIn.priceEnd(i-1,j-1) = stockHist(fdend,2);
        MaxIn.perf(i-1,j-1) = stockHist(fdend,2)/stockHist(fdstart,2)-1;
    
        MinIn.Names(i-1,j-1)=tkrIn(minInIdx(i,j));
        MinIn.PrevDate(i-1,j-1)=InPrevDateCube(i,j,minInIdx(i,j));
        MinIn.PostDate(i-1,j-1)=InPostDateCube(i,j,minInIdx(i,j));
        
        idxIn = strcmp(tickersList(:,1),MinIn.Names(i-1,j-1));
        stockHist = E(idxIn).HistStockData(:,1:2);
        fdstart = find(stockHist(:,1)==MinIn.PrevDate(i-1,j-1));
        fdend = find(stockHist(:,1)==MinIn.PostDate(i-1,j-1));
        MinIn.priceStart(i-1,j-1) = stockHist(fdstart,2);
        MinIn.priceEnd(i-1,j-1) = stockHist(fdend,2);
        MinIn.perf(i-1,j-1) = stockHist(fdend,2)/stockHist(fdstart,2)-1;
        
        MaxOut.Names(i-1,j-1)=tkrOut(maxOutIdx(i,j));
        MaxOut.PrevDate(i-1,j-1)=OutPrevDateCube(i,j,maxOutIdx(i,j));
        MaxOut.PostDate(i-1,j-1)=OutPostDateCube(i,j,maxOutIdx(i,j));
        
        idxIn = strcmp(tickersList(:,1),MaxOut.Names(i-1,j-1));
        stockHist = E(idxIn).HistStockData(:,1:2);
        fdstart = find(stockHist(:,1)==MaxOut.PrevDate(i-1,j-1));
        fdend = find(stockHist(:,1)==MaxOut.PostDate(i-1,j-1));
        MaxOut.priceStart(i-1,j-1) = stockHist(fdstart,2);
        MaxOut.priceEnd(i-1,j-1) = stockHist(fdend,2);
        MaxOut.perf(i-1,j-1) = -(stockHist(fdend,2)/stockHist(fdstart,2)-1);
        
        MinOut.Names(i-1,j-1)=tkrOut(minOutIdx(i,j));
        MinOut.PrevDate(i-1,j-1)=OutPrevDateCube(i,j,minOutIdx(i,j));
        MinOut.PostDate(i-1,j-1)=OutPostDateCube(i,j,minOutIdx(i,j));
        
        idxIn = strcmp(tickersList(:,1),MinOut.Names(i-1,j-1));
        stockHist = E(idxIn).HistStockData(:,1:2);
        fdstart = find(stockHist(:,1)==MinOut.PrevDate(i-1,j-1));
        fdend = find(stockHist(:,1)==MinOut.PostDate(i-1,j-1));
        MinOut.priceStart(i-1,j-1) = stockHist(fdstart,2);
        MinOut.priceEnd(i-1,j-1) = stockHist(fdend,2);
        MinOut.perf(i-1,j-1) = -(stockHist(fdend,2)/stockHist(fdstart,2)-1);
          
    end
end

maxInNamesUnique = unique(MaxIn.Names);
minInNamesUnique = unique(MinIn.Names);
maxOutNamesUnique = unique(MaxOut.Names);
minOutNamesUnique = unique(MinOut.Names);

