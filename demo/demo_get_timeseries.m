% Demo get timeseries from PI

% Add path
% addpath("..")


%% Single timeseries
attribute_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1|InsAcPow";
DATA = getPiData(attribute_path, "*-1h", "*+1h", "1s");
figure(1); clf;
plot(DATA.Time, DATA.InsAcPow)


%% Batch multiple timeseries
element_path = "\\BIOSISOFTP1D\SvKrapportering\RengårdK1G1";
listAttributePaths = element_path + ["|GridFreq"; "|InsAcPow"];
DATA = getPiData(listAttributePaths, "2023-04-26 06:39", "2023-04-26 06:43", "250ms");

% Plot 
figure(2); clf; 
ax1 = subplot(2,1,1); 
plot(DATA.Time, DATA.InsAcPow)
ylabel('InsAcPow [MW]')
title('Rengård')
ax2 = subplot(2,1,2); 
plot(DATA.Time, DATA.GridFreq)
ylabel('GridFreq [Hz]')
linkaxes([ax1, ax2],'x')
