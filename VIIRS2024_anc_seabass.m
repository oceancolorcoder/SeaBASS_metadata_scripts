wipe

tLim = 15; % minutes (ship data interpolate from 10 to 5 minutes
dLim = 1; % km for stations.
sLim = 0.9; % m/s ~= 1.75 kt for stations       SOG this cruise
SZALim = 72; % degrees for screening out night (see sun_position below)

datDir = '~/Projects/HyperPACE/field_data/metadata/VIIRS2024/';

%% Ship data RV Nancy Foster 5/20/24 - 6/1/24
% Profiler CTD was broken at one point. Underway SCS data should be okay.
% Trying to process it from raw...

%% Field Logs
inFile1 = [datDir 'VIIRS2024_NF24-05_DALEC_Radiometry_Field_Log.xlsx'];

outFile = [datDir 'VIIRS2024_Ancillary.sb'];
inHeader = [datDir 'VIIRS2024_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Reconcile with Harrison's Field log for station, cloud, seas

% [table, txt] = xlsread(inFile1);
T = readtable(inFile1);
dT1 = datetime(T.StartStationDate_Time,'Format','yyyy MM dd HH:mm','TimeZone','UTC');
dT2 = datetime(T.EndStationDate_Time,'Format','yyyy MM dd HH:mm','TimeZone','UTC');
dateTime = mean([dT1,dT2],2); % Average station time

% % Format an array
% sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12) 
newDataMat = NaN(length(dateTime),12);
newDataMat(:,1) = str2double(T.Station);
newDataMat(:,2) = year(dateTime);
newDataMat(:,3) = month(dateTime);
newDataMat(:,4) = day(dateTime);
newDataMat(:,5) = hour(dateTime);
newDataMat(:,6) = minute(dateTime);
newDataMat(:,7) = floor(second(dateTime)); % all zeros
newDataMat(:,8) = T.lat;
newDataMat(:,9) = T.lon;
newDataMat(:,10) = T.windSpeed;
newDataMat(:,11) = T.Cloud;
newDataMat(:,12) = T.waves;


%% Output
% Also save to .mat for use in DALEC script
ancillary.datetime = dateTime;
ancillary.station = newDataMat(:,1);
ancillary.lat = newDataMat(:,8);
ancillary.lon = newDataMat(:,9);
ancillary.wind = newDataMat(:,10);
ancillary.cloud = newDataMat(:,11);
ancillary.waves = newDataMat(:,12);
save(strrep(outFile,'.sb','.mat'),"ancillary")

fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');

line = '';
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);

% Available:
% sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12)
%
%   SOG is not permissible in SeaBASS
% sog = newDataMat(:,10);
% newDataMat(:,10) = [];

for i=1:size(newDataMat,1)
    % sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12)
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%.1f\n',...
        newDataMat(i,:));
end

fclose(fidOut);
