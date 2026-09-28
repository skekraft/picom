% Test getPiData
%
%Usage:
% result = runtests('test_getpidata')

%Add path
% addpath("..")


%% AF Attribute
attribute_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1|InsAcPow";
DATA = getPiData(attribute_path, "2026-01-01", "2026-01-01 01:00", "10s");
assert(height(DATA) == 361, 'Basic AF Attribute')


%% PI point
pipoint_path = "\\BIOSISOFTP1A\KepWare.SelsforsK06.4.K006Selsfors.HOP G2.Programs.DB_PI.Generator_Effekt_Filt";
DATA = getPiData(pipoint_path, "2026-01-01", "2026-01-01 01:00", "10s");
assert(height(DATA) == 361, 'Basic PI Point')


%% Single timeseries with relative time
attribute_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1|InsAcPow";
DATA = getPiData(attribute_path, "T-1d", "T", "1h");
assert(height(DATA) == 25, 'Relative time range')


%% Multiple timeseries
element_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1";
listAttributePaths = element_path + ["|GridFreq"; "|InsAcPow"];
DATA = getPiData(listAttributePaths, "2026-01-01", "2026-01-01 01:00", "10s");
assert(width(DATA) == 2, 'Multiple time series')


%% Recursive handling of longer time ranges
element_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1";
listAttributePaths = element_path + ["|InsAcPow"];
DATA = getPiData(listAttributePaths, "2026-01-01", "2026-01-03", "1s");
assert(height(DATA) > 150000, 'Recursive handling of longer time ranges')
