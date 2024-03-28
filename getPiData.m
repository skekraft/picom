function [outputArg1,outputArg2] = getPiData(listAttributePaths, startTime, endTime, interval)
arguments
    listAttributePaths (1,:) string
    startTime (1,1) string = "-1d"
    endTime (1,:) string = "*"
    interval (1,:) string = "1h"
end
%getPiData Get Interpolated Data from Osisoft PI Web API
%
% Data = getPiData(attribute_path, startTime, endTime, interval)
%
% Interval as y, mo, d, h, m, s, ms
% https://docs.aveva.com/bundle/af-sdk/page/html/T_OSIsoft_AF_Time_AFTimeSpan.htm
%
% Example 1
% Data = getPiData( "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1|InsAcPow", "2023-04-26 06:35", "2023-04-26 06:50", "1s");
% plot(Data.Time, Data.InsAcPow)


%% History
% 2024-02-07, jnni, File created
% 2024-03-21, jnni, Time parser updates


%% Settings
base_url = 'https://biosisoftp1w.skekraft.se/piwebapi'; %Web API URL


%% Get timeseries data
% Get first
attribute_path = listAttributePaths(1);
TT = getSingleTimeseries(base_url, attribute_path, startTime, endTime, interval);

% If multiple timeseries, use timestamps from first for syncronization
if numel(listAttributePaths)>1
    t1 = string(datetime(TT.Time(1), 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS'));
    t2 = string(datetime(TT.Time(end), 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS'));

    COLLECTION = {};
    COLLECTION{1} = TT;
    for iLoop = 2:numel(listAttributePaths)
        attribute_path = listAttributePaths(iLoop);
        TT = getSingleTimeseries(base_url, attribute_path, t1, t2, interval);
        COLLECTION{iLoop} = TT;
    end
    TT = synchronize(COLLECTION{:});
end

outputArg1 = TT;
end %getPiData



function TT = getSingleTimeseries(base_url, attribute_path, startTime, endTime, interval)
% Get single timeseries
attribute_url = strcat(base_url, '/attributes?path=', attribute_path);
attribute_json = webread(attribute_url);

% Get interpolated data
data_url = strcat(attribute_json.Links.InterpolatedData, ...
    '?startTime=', startTime, ...
    '&endTime=', endTime, ...
    '&interval=', interval);
data_json = webread(data_url);

if isfield(data_json.Items, 'Errors'), 
    error(join(string(struct2cell(data_json.Items.Errors))))
end

%% Output as timetable
% varname = matlab.lang.makeValidName(aName);
varname = {matlab.lang.makeValidName(attribute_json.Name)};

% Parse Time format
% Ex 1: '2023-08-29T22:00:00Z'
% Ex 2: '2023-09-24T12:04:17.5870418Z'

% 1. First try whole seconds, 
try
    Time = datetime({data_json.Items.Timestamp}', 'InputFormat','uuuu-MM-dd''T''HH:mm:ssZ', 'TimeZone','Europe/Stockholm');
    useTimeFormat = "uuuu-MM-dd HH:mm:ss";
catch
    N = numel({data_json.Items.Timestamp});
    Time = NaT(N,1,'TimeZone','Europe/Stockholm');
    useTimeFormat = "uuuu-MM-dd HH:mm:ss.SSS";
end
% 2. secondly try to add with format millliseconds, 
select = find(isnat(Time));
if ~isempty(select)
    Time(select) = datetime({data_json.Items(select).Timestamp}', 'InputFormat','uuuu-MM-dd''T''HH:mm:ss.SSSSSSSZ','TimeZone','Europe/Stockholm');
end
% 3. lastly complete with .NET
% If necessary, complete with slow step by step time conversion
% From PI web docs, Time format is supported by Microsofts .NET
% System.DateTime.TryParse functionality so lets use this as a last resort
%https://biosisoftp1w.skekraft.se/piwebapi/help/topics/time-strings
select = find(isnat(Time));
if ~isempty(select)
    disp(varname)
    disp("Parsing time format, be patient...")
    for iLoop=1:numel(select)
    % for iLoop=1:3
        [a, b] = System.DateTime.TryParse(data_json.Items(iLoop).Timestamp);
        Time(iLoop) = datetime(b.Year, b.Month, b.Day, b.Hour, b.Minute, b.Second, b.Millisecond, 'TimeZone','Europe/Stockholm');
    end
end

% Remove future values appearing as struct
select = cellfun(@isnumeric, {data_json.Items.Value}); 

TT = timetable(...
    Time(select), ...
    [data_json.Items(select).Value]', ...
    'VariableNames',varname);
TT.Properties.VariableUnits = string(attribute_json.DefaultUnitsNameAbbreviation);
% TT.Time.Format = "uuuu-MM-dd HH:mm:ss.SSS";
TT.Time.Format = useTimeFormat;
end %getSingleTimeseries

