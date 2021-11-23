% INDEX REBALANCING MAIN

% 2021-11-11 AM:
% Working on index periodic rebalancing and composition,
% The goal is to preview, some days before the announcement, the stocks 
% that will be out and the ones that will be in.
% First steps: calculate the index composition using the index rules
% TODO: 1) retrive all the investable univere stocks data from bbg
%       2) using the data to calculate the actual index composition


%%%%%%% FTSE MIB RELEVANT DATES  %%%%%%%
% REBALANCING DATES: last friday of March, June, September, November
% DATA CUT-OFF DATES: monday 4 weeks before rebalancing date. 

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
 
 
%% Input session

% input_params: (eventually to be exported in excel files)
input_params.history_start_date = ['01/01/2017'];
input_params.history_end_date = datestr(today-1,'mm/dd/yyyy');
input_params.granularity = "DAILY";
input_params.UniverseTablePathName = "UniverseTable.xlsx";
input_params.Holidays = "BorsaItalianaHolidays.xlsx";
input_params.minimumNumberOfData = 100;

% read the investable universe (maybe a param files)
Holidays = readtable(input_params.Holidays);
InvestableUniverse = readtable(input_params.UniverseTablePathName);


%% create instance of class 'ParallelBBG'
% to parallelize most of the Bloomberg requests presumably needed to build
% objects of class 'asset', IR_Curve, CDS, etc.
BBG_SimultaneousData = [];
% % if false % to exclude parallel download from BBG
    
if ~DataFromBBG.save2disk & ~DataFromBBG.NOBBG % CANNOT BE USED WHEN USING THE 'save to disk feature' or the NOBBG one
    
    disp('Downloading BBG data');
    
    clear BBG_SimultaneousData;
    
    tickersList = InvestableUniverse.Ticker; %% TO BE READ FROM EXCEL
    zeroColumn = repmat({zeros(1)},size(tickersList)); %% just tu use parallelBBG.
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

%% create and fill all the equities objects

e_cnt = 0;
exept_cnt = 0;
for i = 1:numel(tickersListFXe.Var1)
    % get number of shares in InvestableUniverse
    ticker = tickersListFXe.Var1{i};
    idx = find(strcmp(InvestableUniverse.Ticker,ticker));
    shares = InvestableUniverse.Shares(idx);
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
    e_params.holidays = Holidays.Date;
    e_params.bbg_data = BBG_SimultaneousData;
    e_params.shares = shares;
    e_cnt = e_cnt+1;
    try
        E(e_cnt,1) = Equity(e_params);
    catch AM
        disp(["error while creating",e_params.ticker]);
        e_cnt = e_cnt-1;
        exept_cnt = exept_cnt +1;
        exception{exept_cnt} = e_params.ticker;   
    end
end

%% Create the Univers
clear Universe_1

u_params.equities = E;
u_params.minNumData = input_params.minimumNumberOfData;
Universe_1 = Universe(u_params);
    
%%

Universe_1.ftsemibCalculator();








 