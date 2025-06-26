wipe
[fontName,~] = machine_prefs;
% OceanX 2025 had several legs:
% OXR20250108 (name tbd): Maldives to Mayotte, Jan 8 - 16. Raw ship data available. Extracted 
%   spreadsheet for truewind_s1_stbd 1/9 0700 to 1/16 12:20 @ 1 min. No field radiometry logs.
% OXR20250118 (name tbd): Jan 18 - Jan 26. Mayotte to ?? Extracted ship
%   data available with gaps (1/18, 1/26 - 1/31, 2/20 - 3/1, ...)
% OXR20250130 (name tbd): Jan 29 - Feb 20. ?? to ??
% OXR20250338 (name tbd): Feb 28 - Mar 3. Cape Town to Walvis Bay?
% OXR20250306 (name tbd): Mar 7 - Mar 24. Walvis Bay to Mindelo?

%% Setup
tLim = 2; % minutes (ship data at 1 - 2 min)
dLim = 1; % km for stations.
sLim = 0.9; % m/s ~= 1.75 kt for stations       SOG this cruise
SZALim = 72; % degrees for screening out night (see sun_position below)

datDir = '~/Projects/HyperPACE/field_data/metadata/OceanX/';

% OceanX

% Scott's notes transcribed from Hpro
inFile = [datDir 'OceanX notes.xlsx'];

% Harrison's Field Logs
inFile1 = [datDir 'OceanX_OXR20250228_PySAS_Radiometry_Field_Log.xlsx'];
inFile2 = [datDir 'OceanX_OXR20250308_PySAS_Radiometry_Field_Log.xlsx'];

% Mystery extracted ship data True Wind only (Scott?)
%   This has no lat lon. The GPS file has no datetime.
inFile3 = [datDir 'Ship_data/OXR20250108/OXR20250108_truewind_s1_stbd_1min.csv'];
inFile4 = [datDir 'Ship_data/OXR20250108/OXR20250108.sb.txt']; % Harrison compilation of remaining raw files lat,lon,SOG, heading, sal, Wt

% Harrison has three .sb files. Appear to be 2 min resolution ship data 
%   OXR20250228_anc.sb 3/1/19:18 - 3/3/4:20
%   OXR20250306_anc.sb 3/7/8:30 - 3/22/17:10
%   OXR20250118to0323_anc.sb <-- use this
inFile5 = [datDir 'Ship_data/OXR20250118to0323_anc.sb.txt']; % Not really a seabass file

outFile = [datDir 'OceanX_Ancillary.sb'];
inHeader = [datDir 'OceanX_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude
%% End setup

% Establish an empty array from the earliest to the latest times, then
% eliminate where there is no overlap.
dateTimeGlobal = ...
    (datetime(2025,1,9,7,0,0,'TimeZone','UTC'):duration(minutes(2)):datetime(2025,3,23,14,0,0,'TimeZone','UTC'))';

% Format an array
% sta year mon day hour min sec lat lon(9) windSp sst sss(12) cloud seas heading(15)
newDataMat = NaN(numel(dateTimeGlobal),15);

%% Ship data (Harrison's combined file)
table = readtable(inFile5);
dateTime = datetime(table{:,1},table{:,2},table{:,3},table{:,4},table{:,5},table{:,6},'TimeZone','UTC');
lat = table{:,7};
lon = table{:,8};
% stw = table{:,4}; % Speed through the water (stw)
% cog = table{:,4};
sog = table{:,11};
heading = table{:,12};
% airTemp = table{:,7};
% relH = table{:,8}; No seabass field for humidity
sst = table{:,14};
%baro
windSpeed = table{:,9};% m/s
windDir = table{:,10}; % degrees
sss = table{:,13};

fprintf('Matching ship data %s\n',inFile5)
for i=1:length(dateTimeGlobal)
    [dt,dti] = find_nearest(dateTimeGlobal(i),dateTime);
    if abs(dt-dateTimeGlobal(i)) < minutes(tLim)
        newDataMat(i,2) = year(dateTimeGlobal(i));
        newDataMat(i,3) = month(dateTimeGlobal(i));
        newDataMat(i,4) = day(dateTimeGlobal(i));
        newDataMat(i,5) = hour(dateTimeGlobal(i));
        newDataMat(i,6) = minute(dateTimeGlobal(i));
        newDataMat(i,7) = second(dateTimeGlobal(i));
        newDataMat(i,8) = lat(dti);
        newDataMat(i,9) = lon(dti);
        newDataMat(i,10) = windSpeed(dti);
        newDataMat(i,11) = sst(dti);
        newDataMat(i,12) = sss(dti);
        newDataMat(i,15) = heading(dti);
    end
end
clear table dateTime lat lon sog heading sst windSpeed windDir sss


%% Ship data (Harrison's combined with no True Wind 0108-0116)
table = readtable(inFile4);
dateTime = datetime(table{:,1},table{:,2},table{:,3},table{:,4},table{:,5},table{:,6},'TimeZone','UTC');
lat = table{:,7};
lon = table{:,8};
sog = table{:,9};
heading = table{:,10};
sss = table{:,11};
sst = table{:,12};

fprintf('Matching ship data %s\n',inFile4)
for i=1:length(dateTimeGlobal)
    [dt,dti] = find_nearest(dateTimeGlobal(i),dateTime);
    if abs(dt-dateTimeGlobal(i)) < minutes(tLim)
        newDataMat(i,2) = year(dateTimeGlobal(i));
        newDataMat(i,3) = month(dateTimeGlobal(i));
        newDataMat(i,4) = day(dateTimeGlobal(i));
        newDataMat(i,5) = hour(dateTimeGlobal(i));
        newDataMat(i,6) = minute(dateTimeGlobal(i));
        newDataMat(i,7) = second(dateTimeGlobal(i));
        newDataMat(i,8) = lat(dti);
        newDataMat(i,9) = lon(dti);
        newDataMat(i,11) = sst(dti);
        newDataMat(i,12) = sss(dti);
        newDataMat(i,15) = heading(dti);
    end
end
clear table dateTime lat lon sog heading sst sss

%% Ship data (Scott's True Wind csv 0108-0116)
table = readtable(inFile3);
dateTime = datetime(table{:,1},'InputFormat','yyyy-MM-dd''T''HH:mm:ss''Z','TimeZone','UTC');
windSpeed = table{:,4}; % m/s true
fprintf('Matching ship data %s\n',inFile3)
for i=1:length(dateTimeGlobal)
    [dt,dti] = find_nearest(dateTimeGlobal(i),dateTime);
    if abs(dt-dateTimeGlobal(i)) < minutes(tLim)
        newDataMat(i,2) = year(dateTimeGlobal(i));
        newDataMat(i,3) = month(dateTimeGlobal(i));
        newDataMat(i,4) = day(dateTimeGlobal(i));
        newDataMat(i,5) = hour(dateTimeGlobal(i));
        newDataMat(i,6) = minute(dateTimeGlobal(i));
        newDataMat(i,7) = second(dateTimeGlobal(i));        
        newDataMat(i,10) = windSpeed(dti);
    end
end
clear table dateTime windSpeed

%% Reconcile ship data with log data
% Assign stations data from  field logs. For each continuous ship reading,...
% 1. Find the nearest station timestamp within tLim
% 2. Confirm the location is within dLim
% 3. Confirm the ship is not moving more than sLim (where
%       speed-through-water available)

disp('Matching to field logs')

% Scotts' log
table = readtable(inFile,'Sheet','pysas_Dirks_transcription');
dateTime = datetime(table{:,1},'TimeZone','UTC');
timeOfDay = mean([table{:,3} table{:,4}],2); % decimal
dateTime1 = dateTime+timeOfDay;
station1 = 100+table{:,2};
lat1 = mean([table{:,5} table{:,6}],2);
lon1 = mean([table{:,7} table{:,8}],2);
cloud1 = table{:,9};
seas1 = table{:,10};
windSpeed1 = seas1*nan; % not provided

% Harrison's logs
table1 = readtable(inFile2);
table2 = readtable(inFile1);
table2(3:end,:) = []; % Only 2 stations, 5 and 6
% Station names are repeated for different legs. Need to add identifier of
% some kind. Must be numeric for the sake of the array.
for i=1:size(table2,1)
    % zero-padded string, so 05 becomes 205
    table2{i,1} = {sprintf('2%s',string(table2{i,1}))}; % what bologna...
end

table = [table2;table1];
station2 = str2double(table{:,1});
startDatetime = datetime(table{:,3},'InputFormat','yyyy MM dd HH:mm','TimeZone','UTC');
stopDatetime = datetime(table{:,4},'InputFormat','yyyy MM dd HH:mm','TimeZone','UTC');
dateTime2 = mean([startDatetime stopDatetime],2); % Station mid-time
lat2 = table{:,5};
lon2 = table{:,6};
windSpeed2 = table{:,8}; % in kts, not used
seas2 = table{:,10}; % m
cloud2 = table{:,11}; % percent

lat2(lat2==-9999) = nan;
lon2(lon2==-9999) = nan;
windSpeed2(windSpeed2==-9999) = nan;
seas2(seas2==-9999) = nan;
cloud2(cloud2==-9999) = nan;

% Merge logs
dateTime = [dateTime1;dateTime2];
station = [station1;station2];
lat = [lat1;lat2];
lon = [lon1;lon2];
windSpeed = [windSpeed1;windSpeed2];
seas = [seas1;seas2];
cloud = [cloud1;cloud2];

lat1 = newDataMat(:,8);
lon1 = newDataMat(:,9);
for i=1:length(dateTimeGlobal)    
    [nearTime2, index] = find_nearest(dateTimeGlobal(i),dateTime);
    % Within tLim min and stationary
    tDiff = abs(dateTimeGlobal(i) - nearTime2);
    if tDiff < minutes(tLim)
        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat(index)); 
        dlon = kpdlon*(lon1(i) - lon(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if dist < dLim
            % if stw(i) < sLim
                % sta year mon day hour min sec lat lon(9) windSp sst sss(12) cloud seas heading(15)                
                newDataMat(i,1) = station(index);
                newDataMat(i,13) = cloud(index);
                newDataMat(i,14) = seas(index);
                % newDataMat(i,16) = dist;
                fprintf('Match Station: %d\n', station(index))
            % else
            %     fprintf('Station: %d, Too fast: %.1f\n', station(index), stw(i))
            %     newDataMat(i,1) = -9999;
            %     newDataMat(i,13) = -9999;
            %     newDataMat(i,14) = -9999;
            %     % newDataMat(i,16) = -9999;
            % end
        else
            % fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
            newDataMat(i,1) = nan;
            newDataMat(i,13) = nan;
            newDataMat(i,14) = nan;
            % newDataMat(i,16) = -9999;
        end
    else
        % fprintf('Station: %d, Too much time: %1.0f min\n', station(index),minutes(tDiff))
        newDataMat(i,1) = nan;
        newDataMat(i,13) = nan;
        newDataMat(i,14) = nan;
        % newDataMat(i,16) = -9999;
    end
end


%% Remove met data from before and after the beginning and end of SAS files
noData(:,1) = isnan(newDataMat(:,8));
noData(:,2) = isnan(newDataMat(:,9));
noData = any(noData,2);
newDataMat(noData,:) = [];

% Review data
dateTime = datetime(...
    newDataMat(:,2),newDataMat(:,3),newDataMat(:,4),newDataMat(:,5),newDataMat(:,6),newDataMat(:,7),...
    'TimeZone','UTC');

%%
fh = figure('Position',[1904         306        1116         701]);
subplot(5,1,1)
plot(dateTime,newDataMat(:,9),'.')
ylabel('lon')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

subplot(5,1,2)
plot(dateTime,newDataMat(:,10),'.')
ylabel('wind')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

subplot(5,1,3)
plot(dateTime,newDataMat(:,11),'.')
ylabel('sst')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

subplot(5,1,4)
plot(dateTime,newDataMat(:,13),'.')
ylabel('cloud')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

subplot(5,1,5)
plot(dateTime,newDataMat(:,14),'.')
ylabel('seas')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

exportgraphics(fh,'plt/OceanX_timeline.png')

%%
newDataMat(isnan(newDataMat)) = -9999;
%% Output

fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');

line = '';
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);

% Available:
% sta year mon day hour min sec lat lon(9) windSp sst sss(12) cloud seas heading(15)

for i=1:size(newDataMat,1)
                  % sta year mon day hour min sec lat lon(9) windSp sst sss(12) cloud waveht heading(15)   
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%.1f,%d,%.1f,%03.0f\n',...
        newDataMat(i,:));
end

fclose(fidOut);