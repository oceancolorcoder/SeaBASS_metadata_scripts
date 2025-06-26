wipe

tLim = 15; % minutes (ship data interpolate from 10 to 5 minutes
dLim = 1; % km for stations.
sLim = 0.9; % m/s ~= 1.75 kt for stations       SOG this cruise
SZALim = 72; % degrees for screening out night (see sun_position below)

datDir = '~/Projects/HyperPACE/field_data/metadata/PACE_PAX/';

%% Shearwater ship data lost according to Elena 

%% pySAS GPS data
pyDir =  '~/Projects/HyperPACE/field_data/HyperSAS/PACE-PAX/RAW/pysas/';

%% NOAA Buoy Data
% Offshore (10 min resolution)
% Station 46053 (LLNR 196) - EAST SANTA BARBARA - 12NM Southwest of Santa Barbara, CA
% Owned and maintained by National Data Buoy Center
% 34.241 N 119.839 W (34°14'26" N 119°50'20" W) by UTC
%   Only 10 minute resolution available for these dates
inFile1 = [datDir 'Station_46053_202409_clipped.csv']; 

% Nearshore (6 min resolution)
% Station NTBC1 - 9411340 - Santa Barbara, CA
% Owned and maintained by NOAA's National Ocean Service
% 34.405 N 119.692 W (34°24'17" N 119°41'33" W) by UTC
inFile2 = [datDir 'Station_NTBC_2024_09_clipped.csv']; 

%% PACE_PAX Harrison's Field Logs
inFile3 = [datDir 'PACEPAX_PACEPAX2024_PySAS_Radiometry_Field_Log.xlsx'];

%% AERNET-MAN Shearwater AOD
% Due to the research and development phase characterizing AERONET-MAN; 
% use of data requires offering co-authorship to Principal Investigators.
% PI=Robert Foster,Email=robert.j.foster190.civ@us.navy.mil
% Microtops
inFile4 = [datDir 'Shearwater_24_0/AOD/Shearwater_24_0_all_points.lev20'];

outFile = [datDir 'PACE_PAX_Ancillary.sb'];
inHeader = [datDir 'PACE_PAX_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude



%% Recreate ship file using pySAS GPS
fileList = dir(fullfile(pyDir,"GPS*.csv"));

for i=1:length(fileList)
    T = readtable(fullfile(pyDir,fileList(i).name));
    if i==1
        dateTime = datetime(T.gps_datetime,'InputFormat','yyyy/MM/dd HH:mm:ss.SSSSSS', 'TimeZone','UTC');
        lat = T.latitude;
        lon = T.longitude;
    else
        dateTime = [dateTime;datetime(T.gps_datetime,'InputFormat','yyyy/MM/dd HH:mm:ss.SSSSSS', 'TimeZone','UTC')];
        lat = [lat;T.latitude];
        lon = [lon;T.longitude];
    end
end
% Eliminate garbage
whrBad = find(lat == 0 | lon == 0);
dateTime(whrBad) = [];
lat(whrBad) = [];
lon(whrBad) = [];
whrBad = find(lat > 35 | lon > 0);
dateTime(whrBad) = [];
lat(whrBad) = [];
lon(whrBad) = [];
whrBad = find(isnat(dateTime) | isnan(lat) | isnan(lon));
dateTime(whrBad) = [];
lat(whrBad) = [];
lon(whrBad) = [];
[dateTime,ia,ic] = unique(dateTime);
lat = lat(ia);
lon = lon(ia);

% Sort
[dateTime,idx] = sortrows(dateTime);
lat = lat(idx);
lon = lon(idx);

% Interpolate to 5 min
startTime = dateTime(1);
endTime = dateTime(end);
dateTime0 = startTime:minutes(5):endTime;
lat0 = interp1(dateTime,lat,dateTime0);
lon0 = interp1(dateTime,lon,dateTime0);

% % Format an array
% sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12) aot550(13)
newDataMat = NaN(length(dateTime0),13);
newDataMat(:,2) = year(dateTime0);
newDataMat(:,3) = month(dateTime0);
newDataMat(:,4) = day(dateTime0);
newDataMat(:,5) = hour(dateTime0);
newDataMat(:,6) = minute(dateTime0);
newDataMat(:,7) = floor(second(dateTime0)); % all zeros
newDataMat(:,8) = lat0;
newDataMat(:,9) = lon0;

% % Truncate
% startDT = datetime(2024,5,2,3,50,00,'TimeZone','UTC'); % First pySAS raw file
% endDT = datetime(2024,5,13,3,10,00,'TimeZone','UTC'); % Last pySAS raw file


%% Buoy1 data (offshore)

T = readtable(inFile1);
dateTime1 = datetime(T.x_YY, T.MM, T.DD, T.hh, T.mm, 0,'TimeZone','UTC');
lat1 = repmat(34.241,1,size(T,1));
lon1 = repmat(-119.839,1,size(T,1));
wind1 = T.WSPD; % m/s

% Eliminate garbage
whrBad = find(wind1 >98);
dateTime1(whrBad) = [];
lat1(whrBad) = [];
lon1(whrBad) = [];
wind1(whrBad) = [];

%% Buoy2 data (onshore)

T = readtable(inFile2);
dateTime2 = datetime(T.x_YY, T.MM, T.DD, T.hh, T.mm, 0,'TimeZone','UTC');
lat2 = repmat(34.405,1,size(T,1));
lon2 = repmat(-119.692,1,size(T,1));
wind2 = T.WSPD; % m/s
% Eliminate garbage
whrBad = find(wind2 >98);
dateTime2(whrBad) = [];
lat2(whrBad) = [];
lon2(whrBad) = [];
wind2(whrBad) = [];


%% Reconcile pySAS GPS to inshore vs offshore buoy interpolating windspeed by distance

for i=1:length(newDataMat)
    [nearTime1, index1] = find_nearest(dateTime0(i),dateTime1);
    [nearTime2, index2] = find_nearest(dateTime0(i),dateTime2);
    tDiff1 = abs(dateTime0(i) - nearTime1);
    tDiff2 = abs(dateTime0(i) - nearTime2);    

    kpdlon = kpdlat*cos(pi*lat0(i)/180);
    dlat = kpdlat*(lat1(index1) - lat0(i));
    dlon = kpdlon*(lon1(index1) - lon0(i));
    dist1 = sqrt(dlat.^2 + dlon.^2); % distance to buoy [km]
    dlat = kpdlat*(lat2(index2) - lat0(i));
    dlon = kpdlon*(lon2(index2) - lon0(i));
    dist2 = sqrt(dlat.^2 + dlon.^2); % distance to buoy [km]

    % fprintf('Dist to 1: %.1f km, to 2: %.1f km\n',dist1,dist2)
    % fprintf('tDiff to 1: %s, to 2: %s\n',tDiff1,tDiff2)
    if dist1 < dist2
        dR = dist1/(dist1+dist2);
        wind = wind1(index1) + dR*(wind2(index2) - wind1(index1));
    else
        dR = dist2/(dist1+dist2);
        wind = wind2(index2) + dR*(wind1(index1) - wind2(index2));
    end

    newDataMat(i,10) = wind;

end



%% Reconcile with Harrison's Field log for station, cloud, seas

[table, txt] = xlsread(inFile3);
lat3 = table(:,1);
lon3 = table(:,2);
wind3 = table(:,5);
seas = table(:,7); % m
cloud = table(:,8)*100; % percent
dateTime3 = datetime(txt(7:end,3),'InputFormat','yyyy MM dd HH:mm','TimeZone','UTC');
station = txt(7:end,1); % cell array of strings
for i=1:length(station)
    station3(i) = str2double(station{i}(8:9));
end
station = station3;

%% Reconcile the newDataMat and field log

% Now assign the stations data. For each continuous ship reading,...
% 1. Find the nearest station timestamp within tLim
% 2. Confirm the location is within dLim                (no lat lon in field logs this cruise)
% 3. Confirm the ship is not moving more than sLim

for i=1:length(dateTime0)

    [nearTime3, index] = find_nearest(dateTime0(i),dateTime3);
    % Within tLim min and stationary
    tDiff = abs(dateTime0(i) - nearTime3);
    if tDiff <= minutes(tLim)

        kpdlon = kpdlat*cos(pi*lat0(i)/180);
        dlat = kpdlat*(lat0(i) - lat3(index));
        dlon = kpdlon*(lon0(i) - lon3(index));
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]

        if dist < dLim || isnan(dist)
        % if sog(i) < sLim
            % sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12)
            newDataMat(i,1) = station(index);
            newDataMat(i,11) = cloud(index);
            newDataMat(i,12) = seas(index);
            %                 newDataMat(i,16) = dist;
            fprintf('Match Station: %d\n', station(index))
        % else
        %     fprintf('Station: %d, Too fast: %.2f\n', station(index), sog(i))
        %     newDataMat(i,1) = -9999;
        %     newDataMat(i,14) = -9999;
        %     newDataMat(i,15) = -9999;
        %     %                 newDataMat(i,16) = -9999;
        % end
        else
            fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
            newDataMat(i,1) = -9999;
            newDataMat(i,11) = -9999;
            newDataMat(i,12) = -9999;
            %             newDataMat(i,16) = -9999;
        end
    else
        fprintf('Station: %d, Too much time: %1.0f min\n', station(index),minutes(tDiff))
        newDataMat(i,1) = -9999;
        newDataMat(i,11) = -9999;
        newDataMat(i,12) = -9999;
        %         newDataMat(i,16) = -9999;
    end
end

newDataMat(isnan(newDataMat)) = -9999;

%% AERONET AOD data from the Shearwater (Version 3; LEVEL 2.0 Maritime Aerosol Network (MAN) Measurements)
opts = detectImportOptions(inFile4,'FileType','text');
opts = setvaropts(opts,"Date_dd_mm_yyyy_",'Type','datetime');
opts = setvaropts(opts,"Date_dd_mm_yyyy_",'inputFormat','dd:MM:uuuu');
T = readtable(inFile4,opts);
dateTime4 = datetime((T.Date_dd_mm_yyyy_ + T.Time_hh_mm_ss_), 'timeZone','UTC','Format','dd-MMM-uuuu HH:mm:ss');
% Need AOT(550)
AOT = [T.AOD_340nm T.AOD_440nm T.AOD_500nm T.AOD_675nm T.AOD_870nm];
AOT(AOT==-999) = nan;
wave = [340 440 500 675 870]; % 340 and 500 are NaN
AOT550 = interp1(wave([2 4]),AOT(:,[2 4])',550)';

%% Reconcile the newDataMat and AOT
% 1. Find the nearest station timestamp within tLim
% Bump up the tLim for AOT
tLim = 30;

for i=1:length(dateTime0)

    [nearTime3, index] = find_nearest(dateTime0(i),dateTime4);
    % Within tLim min and stationary
    tDiff = abs(dateTime0(i) - nearTime3);
    if tDiff <= minutes(tLim)
        % kpdlon = kpdlat*cos(pi*lat0(i)/180);
        % dlat = kpdlat*(lat0(i) - lat3(index));
        % dlon = kpdlon*(lon0(i) - lon3(index));
        % dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        % 
        % if dist < dLim || isnan(dist)
        % % if sog(i) < sLim
            % sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12) aot550
            newDataMat(i,13) = AOT550(index);
            fprintf('Match AOT: %.3f\n', AOT550(index))
        % else
        %     fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
        %     newDataMat(i,13) = nan;
        % end
    else
        fprintf('AOT: %.3f, Too much time: %1.0f min\n', AOT550(index),minutes(tDiff))
        newDataMat(i,13) = -9999;
    end
end

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
% sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12)
%
%   SOG is not permissible in SeaBASS
% sog = newDataMat(:,10);
% newDataMat(:,10) = [];

for i=1:size(newDataMat,1)
    % sta year mon day hour min sec lat lon(9) windSp(10) cloud seas(12) aot550
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%.1f,%.3f\n',...
        newDataMat(i,:));
end

fclose(fidOut);
