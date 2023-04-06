wipe

tLim_minor = 1.5; % minutes (Raw ship data are ~ 1 minute resolution after reduction from 1 Hz)
tLim_major = 30; % minutes (COPS log of stations)

dLim = 1000; % km for stations. %%%%%%%%% Log issue, ignore distance

sLim = 0.9; % m/s ~= 1.75 kt for stations (SOG here)
SZALim = 75; % degrees for screening out night (see sun_position below)

datDir = '~/Projects/HyperPACE/field_data/metadata/VIIRS2022/';

% %% Ship data courtesy of Nicholas Sucher, Chief Scientist, Oscar Sette,
% Nov 29, 2022
inFilesGPS = [ datDir 'ship/GPS/LAT_LON/*RAW.log'];
inFilesSOG = [ datDir 'ship/GPS/SOG/*RAW.log']; % No speed through water available
% inFilesWind1 = [ datDir 'ship/Meteorology/nws/*TrueWindDir*.log']; not needed yet
inFilesWind2 = [ datDir 'ship/Meteorology/nws/*TrueWind-Spd*.log'];
inFilesTSG = [ datDir 'ship/TSG/*.xlsx'];

% Scott's field notes
% Contains COPS station info
inFile2 = [datDir 'VIIRS_2022_station_notes_FSG.xlsx'];

outFile = [datDir 'VIIRS2022_Ancillary.sb'];
inHeader = [datDir 'VIIRS2022_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

% Truncate
% startDT = datetime(2022,3,9,23,34,22,'TimeZone','UTC'); % Crossing out of the Honolulu reef
startDT = datetime(2022,3,9,14,20,00,'TimeZone','UTC'); % First leaving the dock
% startDT = datetime(2022,1,9,14,20,00,'TimeZone','UTC'); % ignore for a momemnt
endDT = datetime(2022,3,18,23,16,31,'TimeZone','UTC'); % Crossing into the Honolulu reef
% endDT = datetime(2022,8,18,23,16,31,'TimeZone','UTC'); % ignore

%% GPS Lat/Lon (GPGGA formatted; ~ 1/s)
inFiles = dir(inFilesGPS);
% % Format an array
% sta year mon day hour min sec lat lon(9) SOG windSp sst sss(13) cloud seas(15)
newDataMat = NaN(5000,15); % arbitrary
dateTime1 = NaT(5000,1,'TimeZone','UTC');
index = 0;
for f=1:length(inFiles)
    fpf = fullfile(inFiles(f).folder, inFiles(f).name);

    fprintf('Reading %s\n',inFiles(f).name)

    table = readtable(fpf);
    dateTimeCell = table{:,1};

    % BEWARE of redundant records
    [C, ia, ic] = unique(dateTimeCell);
    table = table(ia,:);
    dateTimeCell = C;

    lat = table{:,5}; % DDMM.MMMM N
    lon = table{:,7};% DDDMM.MMMM W

    lat1 = NaN(length(dateTimeCell),1);
    lon1 = lat1;

    % SCS file has 1 per minute. Subsample to 1/minute
    subSamp = 0;

    for i=1:length(dateTimeCell)
        subSamp = subSamp +1;
        if subSamp >= 60
            try
                latStr = sprintf('%010.4f',lat(i));
                lat1(i) = str2double(latStr(1:3)) + str2double(latStr(4:end))/60; % N is +
                lonStr = sprintf('%010.4f',lon(i));
                lon1(i) = -1* ( str2double(lonStr(1:3)) + str2double(lonStr(4:end))/60 ); % E is +
                year = str2double(dateTimeCell{i}(1:4));
                month = str2double(dateTimeCell{i}(6:7));
                day = str2double(dateTimeCell{i}(9:10));
                hour = str2double(dateTimeCell{i}(12:13));
                minute = str2double(dateTimeCell{i}(15:16));
                second = str2double(dateTimeCell{i}(18:end-1)); % Z UTC

                DT = datetime(year, month, day, hour, minute, second,'TimeZone','UTC');
                location.latitude = lat1(i);
                location.longitude = lon1(i);
                sun = sun_position(DT,location);
                if (DT > startDT) && (DT < endDT) && (sun.zenith < SZALim)
                    index = index+1;

                    dateTime1(index) = DT;
                    % stn year month day hour minute sec lat lon(9) speed wind sst
                    % sss(13) cloud(14) seas(15)
                    newDataMat(index,:) = [-9999, year, month, day, hour, minute, floor(second), lat1(i), lon1(i), ...
                        -9999, -9999, -9999, -9999, -9999, -9999];
                elseif (DT > startDT) && (DT < endDT) && (sun.zenith >= SZALim)
                    fprintf('SZA lim exceded: %.1f at %s UTC (%s local)\n',sun.zenith,DT, DT-hours(10))
                end

                % reset counter
                subSamp = 0;
            catch
                disp('Error reading from table.')
            end
        end
    end

    clear lat* lat* year month day hour minute second subSamp table dateTimeCell

end

%% SOG (~ 1 Hz; doesn't start until 3/12/22 21:04:06)
inFiles = dir(inFilesSOG);
% sta year mon day hour min sec lat lon(9) SOG windSp sst sss(13) cloud seas(15)
for f=1:length(inFiles)
    fpf = fullfile(inFiles(f).folder, inFiles(f).name);

    fprintf('Reading %s\n',inFiles(f).name)

    table = readtable(fpf);
    dateTimeCell = table{:,1};

    % BEWARE of redundant records
    [C, ia, ic] = unique(dateTimeCell);
    table = table(ia,:);
    dateTimeCell = C;

    % Lat/Lon file has 1 per minute. This files has 1/s. Skip 30, match to
    % 1/minute from above
    subSamp = 0;

    for i=1:length(dateTimeCell)
        subSamp = subSamp +1;
        if subSamp >= 30
            try
                year = str2double(dateTimeCell{i}(1:4));
                month = str2double(dateTimeCell{i}(6:7));
                day = str2double(dateTimeCell{i}(9:10));
                hour = str2double(dateTimeCell{i}(12:13));
                minute = str2double(dateTimeCell{i}(15:16));
                second = str2double(dateTimeCell{i}(18:end-1)); % Z UTC

                DT = datetime(year, month, day, hour, minute, second,'TimeZone','UTC');
                if (DT > startDT) && (DT < endDT)

                    [nearDT,nearI] = find_nearest(DT,dateTime1);
                    if abs(nearDT - DT) <= minutes(tLim_minor)

                        % stn year month day hour minute sec lat lon(9) speed wind sst
                        % sss(13) cloud(14) seas(15) dist(16) shipGyro(17)
                        newDataMat(nearI,10) = table{i,4} /1.9438; % knots to m/s
                    end
                end
                % reset counter
                subSamp = 0;
            catch
                disp('Error reading from table.')
            end
        end

    end

    clear year month day hour minute second table dateTimeCell
end


%% Wind
inFiles = dir(inFilesWind2);
% sta year mon day hour min sec lat lon(9) SOG windSp sst sss(13) cloud seas(15)
for f=1:length(inFiles)
    fpf = fullfile(inFiles(f).folder, inFiles(f).name);

    fprintf('Reading %s\n',inFiles(f).name)

    table = readtable(fpf);
    dateTimeCell = table{:,1};

    % BEWARE of redundant records
    [C, ia, ic] = unique(dateTimeCell);
    table = table(ia,:);
    dateTimeCell = C;

    % Lat/Lon file has 1 per minute. This files has 1/s. Skip 30, match to
    % 1/minute from above
    subSamp = 0;

    for i=1:length(dateTimeCell)
        subSamp = subSamp +1;
        if subSamp >= 30
            try
                year = str2double(dateTimeCell{i}(1:4));
                month = str2double(dateTimeCell{i}(6:7));
                day = str2double(dateTimeCell{i}(9:10));
                hour = str2double(dateTimeCell{i}(12:13));
                minute = str2double(dateTimeCell{i}(15:16));
                second = str2double(dateTimeCell{i}(18:end-1)); % Z UTC

                DT = datetime(year, month, day, hour, minute, second,'TimeZone','UTC');
                if (DT > startDT) && (DT < endDT)

                    [nearDT,nearI] = find_nearest(DT,dateTime1);
                    if abs(nearDT - DT) <= minutes(tLim_minor)

                        % stn year month day hour minute sec lat lon(9) SOG wind sst
                        % sss(13) cloud(14) seas(15) 
                        newDataMat(nearI,11) = table{i,4}/1.9438; % knots to m/s
                    end
                end
                % reset counter
                subSamp = 0;
            catch
                disp('Error reading from table.')
            end
        end
    end

    clear year month day hour minute second table dateTimeCell
end

%% Temp, Sal (TSG, 1/3s)
inFiles = dir(inFilesTSG);
% sta year mon day hour min sec lat lon(9) SOG windSp sst sss(13) cloud seas(15)
for f=1:length(inFiles)
    fpf = fullfile(inFiles(f).folder, inFiles(f).name);
    if ~contains(fpf,'~$') % avoid open file copies

        fprintf('Reading %s\n',inFiles(f).name)

        table = readtable(fpf);
        dateDT = datetime(table{:,2},'timezone','UTC'); % datetimes UTC
        todDouble = table{:,3};
        dateTimeDT = dateDT+days(todDouble);

        % Lat/Lon file has 1 per minute. This files has 1/3s. Skip 10, match to
        % 1/minute from above
        subSamp = 0;

        for i=1:length(dateTimeDT)
            subSamp = subSamp +1;
            if subSamp >= 10
                try

                    DT = dateTimeDT(i);
                    if (DT > startDT) && (DT < endDT)

                        [nearDT,nearI] = find_nearest(DT,dateTime1);
                        if abs(nearDT - DT) <= minutes(tLim_minor)

                            % stn year month day hour minute sec lat lon(9) SOG wind sst
                            % sss(13) cloud(14) seas(15)
                            newDataMat(nearI,12) = str2double(table{i,6});
                            newDataMat(nearI,13) = str2double(table{i,7});
                        end
                    end
                    % reset counter
                    subSamp = 0;
                catch
                    disp('Error reading from table.')
                end
            end
        end

        clear year month day hour minute second table dateCell todDouble dateTimeDT
    end
end

% Tidy up
x = isnat(dateTime1);
dateTime1(x) = [];
newDataMat(x,:) = [];

%% Scott's notes for COPS station log for station, cloud and seas (first worksheet in inFile2)

[table, txt] = xlsread(inFile2,'Sheet1'); %COPS metadata (Scott)

datenum2 = table(:,3)+table(:,7)+693960; % Begin COPS datetime
dateTime2 = datetime(datenum2,'convertfrom','datenum','TimeZone','UTC');
station = table(:,1);
cloud = table(:,14); % [%]
seas = table(:,13); % [m]
lat2 = table(:,10); %
lon2 = table(:,11);

lat1 = newDataMat(:,8);
lon1 = newDataMat(:,9);
sog = newDataMat(:,10);

% Reconcile the two tables (Ship data and COPS log)

%Now assign the stations data. For each continuous ship reading,...
% 1. Find the nearest station timestamp within tLim
% 2. Confirm the location is within dLim
% 3. Confirm the ship is not moving more than sLim

for i=1:length(dateTime1)
    
    [nearTime2, index] = find_nearest(dateTime1(i),dateTime2);
    % Within tLim min and stationary
    tDiff = abs(dateTime1(i) - nearTime2);
    if tDiff <= minutes(tLim_major)

        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat2(index));
        dlon = kpdlon*(lon1(i) - lon2(index));
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]

        if dist < dLim || isnan(dist)
            if sog(i) < sLim
                % stn year month day hour minute sec lat lon(9) SOG wind sst
                % sss(13) cloud(14) seas(15)
                newDataMat(i,1) = station(index);
                newDataMat(i,14) = cloud(index);
                newDataMat(i,15) = seas(index);
%                 newDataMat(i,16) = dist;
                fprintf('Match Station: %d\n', station(index))
            else
                fprintf('Station: %d, Too fast: %.2f\n', station(index), sog(i))
                newDataMat(i,1) = -9999;
                newDataMat(i,14) = -9999;
                newDataMat(i,15) = -9999;
%                 newDataMat(i,16) = -9999;
            end
        else
            fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
            newDataMat(i,1) = -9999;
            newDataMat(i,14) = -9999;
            newDataMat(i,15) = -9999;
%             newDataMat(i,16) = -9999;
        end
    else
        fprintf('Station: %d, Too much time: %1.0f min\n', station(index),minutes(tDiff))
        newDataMat(i,1) = -9999;
        newDataMat(i,14) = -9999;
        newDataMat(i,15) = -9999;
%         newDataMat(i,16) = -9999;
    end
end

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
% stn year month day hour minute sec lat lon(9) SOG wind sst sss(13) cloud(14) seas(15) 
%
%   SOG is not permissible in SeaBASS
newDataMat(:,10) = [];

for i=1:size(newDataMat,1)
    % sta year mon day hour min sec lat lon wind sst sss cloud seas
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.2f,%.2f,%.1f,%.1f\n',...
        newDataMat(i,:));
end

fclose(fidOut);