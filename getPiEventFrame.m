function DATA = getPiEventFrame(options)
arguments
    options.db_path (1,1) string = "\\BIOSISOFTP1D\SvKrapportering"
    options.TemplateName (1,1) string = ""
    options.maxCount (1,1) {mustBeNumeric,mustBeReal}  = 100
    options.Start (1,:) = ''
    options.End (1,:) = ''
end
%getPiEventFrame Get Event Frames from Osisoft PI Web API
%
% Data = getPiEventFrame(options)
%
% using action GetEventFramesQuery from EventFrame  controller, See PI Web API Reference
% https://docs.aveva.com/bundle/pi-web-api-reference/page/help/controllers/eventframe.html
%
% Example 1
% EventFrames = getPiEventFrame("TemplateName", "Stödtjänstkvlificering")


%% History
% 2025-09-29, jnni, File created /Johan Nilsson


%% Settings
verbose = 0; %0=quiet, 1=normal, 2=debug
base_url = 'https://biosisoftp1w.skekraft.se/piwebapi'; %Web API URL
% db_path = "\\BIOSISOFTP1D\SvKrapportering"; %Path to database
% databaseWebId = "F1RDM8hl-DAgCkm9fssTogg8gwmu-Kz-_HLkeddOvxfi6IwQQklPU0lTT0ZUUDFEXFNWS1JBUFBPUlRFUklORw";
% TemplateName = "Stödtjänstkvalificering";
% maxCount = 100;

% Database connection
url = strcat(base_url, '/assetdatabases', ...
    '?path=', options.db_path ...
    );
DataBase_json = webread(url);
databaseWebId = DataBase_json.WebId;

% Query Event Frames
url = strcat(base_url, '/eventframes/search', ...
    '?databaseWebId=', databaseWebId, ...
    '&maxCount=', string(options.maxCount) ...
    );
if ~isempty(options.TemplateName) | ~isempty(options.Start) | ~isempty(options.End)
    querystring = strcat("&query=TemplateName:=", options.TemplateName);
    if ~isempty(options.Start)
        querystring = strcat(querystring, " Start:>=", string(options.Start));
    end
    if ~isempty(options.End)
        querystring = strcat(querystring, " End:<", string(options.End));
    end
    url = url+querystring;
end
if verbose>1, disp(url); end


% '&selectedFields=', "Items.Name;Items.StartTime;Items.EndTime;Items.Id;Items.RefElementWebIds" ...
EventFrames_json = webread(url);
if isempty(EventFrames_json.Items)
    DATA = table;
    return
end
DATA = struct2table(EventFrames_json.Items, "AsArray", true);
DATA.Name = string(DATA.Name);
DATA.StartTime = datetime(DATA.StartTime, 'InputFormat', 'uuuu-MM-dd''T''HH:mm:ss''Z''', 'TimeZone','UTC');
DATA.EndTime = datetime(DATA.EndTime, 'InputFormat', 'uuuu-MM-dd''T''HH:mm:ss''Z''', 'TimeZone','UTC');
DATA.StartTime.Format = 'uuuu-MM-dd HH:mm:ss';
DATA.EndTime.Format = 'uuuu-MM-dd HH:mm:ss';
DATA.StartTime.TimeZone = "Europe/Stockholm";
DATA.EndTime.TimeZone = "Europe/Stockholm";
% DATA = DATA(:,["Name","StartTime","EndTime","RefElementWebIds","Links"]);

%Augment DATA
DATA.id = (1:height(DATA))';
D = table;
for iLoop = 1:height(DATA)
    id = DATA.id(iLoop);

    %Referenced Element Name
    webId=DATA.RefElementWebIds{iLoop};
    url = strcat(base_url, '/elements', ...
        '/', webId, ...
        '?selectedFields=', "Name" ...
        );
    element = webread(url);
    Element_Name = string(element.Name);

    % Event Frame attributes
    url = DATA.Links(iLoop).Value;
    Value_json = webread(url);
    S = struct2table(Value_json.Items);
    S = S(:,["Name", "Value"]);
    S.Name = string(S.Name);
    S.Value = string({S.Value.Value})';

    %Collect
    D = [D;table(id, Element_Name) unstack(S, "Value", "Name")];
end
DATA = join(DATA, D, 'Keys', 'id');
% DATA = removevars(DATA, ["RefElementWebIds","Links", "id"]);
DATA = removevars(DATA, "id");

return


