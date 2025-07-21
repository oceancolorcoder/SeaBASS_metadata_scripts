% FRM4SOC2 FICE2025 training data, July 2025
wipe % clear close all

datDir = '~/Data/FICE2025/Ancillary';

% Fixed location only
lat = 45.314;
lon = 12.508;

% Local time July is UTC+2
startCruise = datetime([2025,7,9,8,0,0],"TimeZone","UTC");
endCruise = datetime([2025,7,9,13,0,0],"TimeZone","UTC");

% Log is start time, so increase density of 5-min met file to 1 minute and
% use start time and start time plus ...
tThresh = minutes(5); 

% Increase data density for sparse sampling (i.e., manual acquisition)
interpDatetime = startCruise:minutes(1):endCruise;


% AAOT tower met data % https://www.comune.venezia.it/content/3-piattaforma-ISMAR-CNR = AAOT
% UTC+1 according to website; i.e., using winter time year round
% date/time(UTC+1) tideht wdir10m wspeed10m wmax10m  wave wavemax pressure temp watertemp humidity solarrad(PAR?) rain
inFile1 = fullfile(datDir,'Stazione_Piattaforma_20250709.xlsx'); 
if ~isfile(inFile1)
    fprintf('%s is not a file\n',inFile1)
end

% Field Log
inFile2 = fullfile(datDir,'FRM4SOC2_FICE2025_SanServolo_Radiometry_Field_Log.xlsx'); 
if ~isfile(inFile2)
    fprintf('%s is not a file\n',inFile2)
end

% AOC.Venice.Aerosol_Optical_Depth
% inFile4 = '~/GitRepos/AERONET/dat/Aeronet_OC_FICE22_20220711_20220722_L15.mat';

inHeader = fullfile(datDir,'FICE2025_SanServolo_Ancillary_header.sb');

outFile = fullfile(datDir,'FICE2025_SanServolo_Ancillary.sb');

%% inFile1: Met data every 5 minutes
fprintf('Read File 1; Met data: %s\n',inFile1)
% date/time(UTC+1) tideht wdir10m wspeed10m wmax10m  wave wavemax pressure temp watertemp humidity solarrad(PAR?) rain
data1 = readtable(inFile1);
dateTime1 = data1.Data;
dateTime1.TimeZone = 'UTC+1';
dateTime1.TimeZone = 'UTC';
notCruise = dateTime1  < startCruise | dateTime1 > endCruise;
dateTime1(notCruise) = [];
data1(notCruise,:) = [];

if isempty(dateTime1)
    fprintf('No overlap between %s and cruise limits\n',inFile1)
end

lat1 = repmat(lat,size(data1,1),1);             % degrees
lon1 = repmat(lon,size(data1,1),1);             % degrees
windDir1 = data1.PiattaformaCNRD_VentoMed_10m;  % degrees
windSpeed1 = data1.PiattaformaCNRV_VentoMed_10m; % m/s at 10m
seas1 = data1.PiattaformaCNROnda_Alt_Max;       % m
sst1 = data1.PiattaformaCNRTemperatura;         % deg C

%% inFile2: Field log
fprintf('Read File 2; Field log: %s\n',inFile2)
data2 = readtable(inFile2);

dateTime2 = data2.stationStartDate_time;
dateTime2.TimeZone = 'UTC';
notCruise = dateTime2  < startCruise | dateTime2 > endCruise;
dateTime2(notCruise) = [];
data2(notCruise,:) = [];

station = data2.station;
cloud2 = data2.cloud; % percent
relAz2 = data2.relativeAzimuth_solar_sensor_; 
lat2 = data2.lat;
lon2 = data2.lon;

%% Reconcile. Walk through first dataset (5min), and tack on station and cloud
dataMat = NaN(height(data1),16);
disp('Looping over met data')
for i=1:height(data1)    
    % /fields=station,year,month,day,hour,minute,second,lat,lon,Wt,wind,wdir,waveht,cloud,sal,relaz
    dataMat(i,2:13) = [dateTime1(i).Year, dateTime1(i).Month, dateTime1(i).Day, ....
        dateTime1(i).Hour, dateTime1(i).Minute, dateTime1(i).Second, ... 
        lat1(i),lon1(i),...
        sst1(i), windSpeed1(i), windDir1(i), seas1(i)];
end
dataMat(isnan(dataMat)) = -9999;

%% Increase data density using nearest neighbor
dataMat = interp1(dateTime1,dataMat,interpDatetime,'nearest');
for i=1:length(dataMat)
    dataMat(i,2) = interpDatetime(i).Year;
    dataMat(i,3) = interpDatetime(i).Month;
    dataMat(i,4) = interpDatetime(i).Day;
    dataMat(i,5) = interpDatetime(i).Hour;
    dataMat(i,6) = interpDatetime(i).Minute;
    dataMat(i,7) = interpDatetime(i).Second;
end
dateTime1 = interpDatetime;

% Loop over sparse log data
for i=1:length(dateTime2)
    startCast = dateTime2(i);
    endCast = startCast + tThresh;
    whr = dateTime1 >= startCast & dateTime1 <= endCast;
    dataMat(whr,1) = repmat(station(i),1,sum(whr));
    dataMat(whr,8) = repmat(lat2(i),1,sum(whr));
    dataMat(whr,9) = repmat(lon2(i),1,sum(whr));
    dataMat(whr,14) = repmat(cloud2(i),1,sum(whr));
    dataMat(whr,16) = repmat(relAz2(i),1,sum(whr));
end

% %% Aerosol Optical Depth from AERONET (-OC, as it happens)
% load(inFile4) % AOC structure
% 
% for i=1:length(dateTime1)
%     [dtMatch,index] = find_nearest(dateTime1(i),AOC.Venise.Datetime);
% 
%     fprintf('Nearest AOT match within %s\n',abs(dateTime1(i)-dtMatch))
% 
%     % THIS MAY BE IMPROVED USING AERONET AOD FILES INSTEAD OF AERONET-OC
%     % FILES 
%    dataMat(i,16) = AOC.Venise.Aerosol_Optical_Depth(index,5); % This may be many hours off, and is at 551.9 nm, not 550 nm
    % dataMat(i,16) = 0.1;
% end


%% Transcribe the sb header and write file
fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');
line = '';

fprintf('Outputing seabass file: %s\n',outFile)
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);

for i=1:size(dataMat,1)
    %               station,year,month,day,hour,minute,second,lat,lon,Wt,wind,wdir,waveht,cloud,sal,relaz
    fprintf(fidOut,'%.3f,%d,%02d,%02d,%02d,%02d,%02d,%.3f,%.3f,%.1f,%.1f,%d,%.1f,%d,%.3f,%.1f\n',dataMat(i,:));
end

fclose(fidOut);

%% Don't forget to fcheck the file.
