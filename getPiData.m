function DATA = getPiData(listAttributePaths, startTime, endTime, interval, DATA_COLLECTION)
arguments
    listAttributePaths (1,:) string
    startTime (1,1) string = "-1d"
    endTime (1,:) string = "*"
    interval (1,:) string = "1h"
    DATA_COLLECTION {mustBeScalarOrEmpty} = timetable
end
%getPiData Get Interpolated Data from Osisoft PI Web API
%
% Data = getPiData(attribute_path, startTime, endTime, interval)
%
% Interval as y, mo, d, h, m, s, ms
% https://docs.aveva.com/bundle/af-sdk/page/html/T_OSIsoft_AF_Time_AFTimeSpan.htm
%
% using action GetInterpolated from Stream controller, See PI Web API Reference
% https://docs.aveva.com/bundle/pi-web-api-reference/page/help/controllers/stream.html
%
% Example 1
% Data = getPiData( "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1|InsAcPow", "2023-04-26 06:35", "2023-04-26 06:50", "1s");
% plot(Data.Time, Data.InsAcPow)

%Notes
% Web API limitation:  "Parameter 'timeRange / intervals' is greater than the maximum allowed (150000)."


%% History
% 2024-02-07, jnni, File created /Johan Nilsson
% 2024-03-21, jnni, Time parser updates
% 2024-05-11, jnni, Reducing size of web response to 30%
% 2024-05-23, jnni, Recursive call workaround for web api limitation
% 2024-10-20, jnni, Accepting relative dates * (without max sample
% recursive handling)
% 2025-04-11, jnni, Bug fix with recursive collection creating duplicate
% timestamps
% 2025-06-17, jnni, Accepting also boolean values from PI. 
% 2025-06-17 jnni, converting all data to double before synchronization
% 2025-09-29, jnni, warning when single timeseies fail, return the rest
% 2026-05-18, jnni, Matlab Memoized to improve performance,workaround for slow PI AF

%% Settings
base_url = 'https://biosisoftp1w.skekraft.se/piwebapi'; %Web API URL
verbose = 0; %0=quiet, 1=normal, 2=debug

% Check inargs
interval_unit = extract(interval, lettersPattern);
interval_number = str2double(extract(interval, digitsPattern));
switch interval_unit
    case "ms"
        dur = seconds(interval_number/1000);
    case "s"
        dur = seconds(interval_number);
    case "m"
        dur = minutes(interval_number);
    case "h"
        dur = hours(interval_number);
    case "d"
        dur = days(interval_number);
    case "y"
        dur = years(interval_number);
    otherwise
        error("Unknown interval")
end

% Max sample recursive handling
% Recursive calling if exceeding limit of max number of samples in web API
% (Only used with fixed datetime, difficult to parse with realtive dates *)
nSamples = NaN;      % Number of requested samples, deafults to unknown
% maxSamples = 150000; % Practical limit from trial and error
maxSamples = 50000; % Reduced limit because of random internal PI errors 2025-02-05
if ~contains(startTime, "*")
    startTime = datetime(startTime, 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS');
    endTime = datetime(endTime, 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS');
    nSamples = (endTime - startTime)/dur;
    nLoop = ceil(nSamples/maxSamples);
    if verbose, fprintf("nLoop=%d, st=%s, et=%s, nSamples=%d\n", ...
            nLoop, string(startTime), string(endTime), nSamples); end
end
if nSamples>maxSamples
    st= startTime + maxSamples*dur;
    DATA = getPiData(listAttributePaths,  st, endTime, interval, DATA_COLLECTION);
    endTime = st-dur;
else
    DATA = timetable;
end


%% Get timeseries data
%Collect one timeseries at a time, then synchronize to singel timetable
COLLECTION = {};
for iLoop = 1:numel(listAttributePaths)
    attribute_path = listAttributePaths(iLoop);
    try
        TT = getSingleTimeseries(base_url, attribute_path, startTime, endTime, interval);

        % If relative time, use timestamps from first for syncronization
        if contains(string(startTime), "*")
            startTime = string(datetime(TT.Time(1), 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS'));
        end
        if contains(string(endTime), "*")
            endTime = string(datetime(TT.Time(end), 'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSS'));
        end
    catch ME
        warning('Failed fetching %s\n%s', attribute_path,ME.message)
        TT = timetable; %Empty
    end
    COLLECTION{iLoop} = TT;
end
COLLECTION = COLLECTION(~cellfun(@isempty, COLLECTION));

% Bool to double before synchronize (one way to include bool)
for iLoop = 1:numel(COLLECTION)
    tmp = COLLECTION{iLoop}.(1);
    if any(islogical(tmp))
        COLLECTION{iLoop}.(1) = double(COLLECTION{iLoop}.(1));
        varname = COLLECTION{iLoop}.Properties.VariableNames{1};
        fprintf("Converting ''%s'' from bool to double before synchronize\n", varname)
    end
end

TT = synchronize(COLLECTION{:});

DATA = [TT; DATA];  %Recursive calling when large number of samples
end %getPiData



% Web API GetByPath has a very slow response around 13 s for single path.
% Selected fields gives no improvement
% https://biosisoftp1w.skekraft.se/piwebapi/attributes?path=\\BIOSISOFTP1D\SvKrapportering\SelsforsK6G1|GridFreq&selectedFields=WebId
% Workaround with Matlab MemoizedFunction to speed up subsequent calls
function attribute_json = getWebId(attribute_url)
attribute_json = webread(attribute_url);
end
% Clear all with: clearAllMemoizedCaches


function TT = getSingleTimeseries(base_url, attribute_path, startTime, endTime, interval)
% Get single timeseries
attribute_url = strcat(base_url, '/attributes?path=', attribute_path);
% attribute_json = webread(attribute_url);
mf = memoize(@getWebId);
mf.CacheSize = 100;
attribute_json = mf(attribute_url);


% Get interpolated data
% Using selectedFields reduces response size to 1/3 
data_url = strcat(attribute_json.Links.InterpolatedData, ...
    '?startTime=', string(startTime), ...
    '&endTime=', string(endTime), ...
    '&interval=', interval, ...
    '&selectedFields=Items.Timestamp;Items.Value');
data_json = webread(data_url);

if isfield(data_json.Items, 'Errors') 
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
% select = cellfun(@isnumeric, {data_json.Items.Value}); %2025-06-17, jnni
select = ~cellfun(@isstruct, {data_json.Items.Value}); 

TT = timetable(...
    Time(select), ...
    [data_json.Items(select).Value]', ...
    'VariableNames',varname);
TT.Properties.VariableUnits = string(attribute_json.DefaultUnitsNameAbbreviation);
% TT.Time.Format = "uuuu-MM-dd HH:mm:ss.SSS";
TT.Time.Format = useTimeFormat;
end %getSingleTimeseries

