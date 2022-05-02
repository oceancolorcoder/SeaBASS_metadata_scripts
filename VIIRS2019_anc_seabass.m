wipe

% Read in Excel data and output SeaBASS formatted data

tLim = 60; % minutes
dLim = 1.5; % km
sLim = 1.5; % m/s ~= 3.0 kts to compensate for Gulf Stream

datDir = '~/Projects_Supplemental/HyperPACE/field_data/metadata/VIIRS2019/';

% Downloaded ship data
% inFile = [ datDir 'SCS_Compaction_VIIRS2019.csv'];
inFile = [ datDir 'SCS_Compaction_merge.csv'];

% Scott's field notes
% Contains COPS station info and SAS pointing info
% SolarTracker broken, turned by hand and recorded in logs
inFile2 = [datDir 'viirs_2019_FSG_Stationlog.xlsx']; 

outFile = [datDir 'VIIRS2019_Ancillary.sb'];
inHeader = [datDir 'VIIRS2019_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Ship data Compactored GU-0_2019-09-19-152550

table = readtable(inFile);
dateTimeCell = table{:,1};

% BEWARE of redundant records
[C, ia, ic] = unique(dateTimeCell);
table = table(ia,:);
dateTimeCell = C;

%%%%%%%%%%%% Beware of SAMOS Lat/Lon, at only two decimal places, it is only
%%%%%%%%%%%% accurate to about 1.1 km or more.
%%%%%%%%%%%% Compactor the GPS Lat/Lon, not SAMOS
lat = table{:,2};
lon = table{:,3};
stw = table{:,4}; % Speed through the water (stw)
% cog = table{:,4};
% sog = table{:,5};
shipGyro = table{:,5}; % SAMOS gyro heading
% airTemp = table{:,7};
% relH = table{:,8}; No seabass field for humidity
sst = table{:,8};
%baro
windSpeed = table{:,7};% m/s
% windDir = table{:,12}; % degrees
sss = table{:,9};

% % Format an array
% sta year mon day hour min sec lat lon(9) stw windSp sst sss(13) cloud seas relAz(16) heading(17)
newDataMat = NaN(numel(dateTimeCell),19);
lat1 = NaN(numel(dateTimeCell),1);
lon1 = lat1;
dateTime1 = NaT(numel(dateTimeCell),1);

% SCS file has 6 per minute. Subsample to 1/minute
subSamp = 0;

for i=1:numel(dateTimeCell)
    subSamp = subSamp +1;
    if subSamp >= 6
        try
            latDD = str2double(lat{i}(1:2));
            latMM = str2double(lat{i}(3:9));
            lat1(i) = latDD + latMM/60;
            lonDD = str2double(lon{i}(1:3));
            lonMM = str2double(lon{i}(4:10));
            lon1(i) = -1*(lonDD + lonMM/60);
            year = str2double(dateTimeCell{i}(1:4));
            month = str2double(dateTimeCell{i}(6:7));
            day = str2double(dateTimeCell{i}(9:10));
            hour = str2double(dateTimeCell{i}(12:13));
            minute = str2double(dateTimeCell{i}(15:16));
            second = str2double(dateTimeCell{i}(18:19));
            dateTime1(i) = datetime(year, month, day, hour, minute, second);
            
            % stn year month day hour minute sec lat lon(9) speed wind sst
            % sss(13) cloud(14) seas(15) dist(16) shipGyro(17) SASgyro(18),
            % relAz(19)
            newDataMat(i,:) = [-9999, year, month, day, hour, minute, second, lat1(i), lon1(i), ...
                stw(i), windSpeed(i), sst(i), sss(i), -9999, -9999, -9999, shipGyro(i), -9999, -9999];
            
            % reset counter
            subSamp = 0;
        catch
            disp('Error reading from Compaction table.')
        end
    end
end

test = newDataMat(:,1);
noData = isnan(test);
newDataMat(noData,:) = [];
dateTime1(noData) = []; lat1(noData) = []; lon1(noData) = []; stw(noData) = [];
clear latDD latMM lonDD lonMM year month day hour minute second subSamp table dateTimeCell
clear lat lon cog windSpeed windDir airTemp sst sss test noData
disp('Compaction table complete')
%% Scott's notes for COPS station log for station, cloud and seas (first worksheet in inFile2)

[table, txt] = xlsread(inFile2,'C-Ops'); %COPS metadata (Scott)
txt(1:10,:) = [];

datenum2 = table(:,4)+693960; % Begin COPS datetime
dateTime2 = datetime(datenum2,'convertfrom','datenum');
station = str2double(txt(:,6));
% wDepth = table(:,7); % [m]
cloud = table(:,8); % [%]
seas = table(:,9); % [m]
% windSpeed = table(:,11);% m/s
% windDir = table(:,12); % degrees
% sss = table(:,13); % [psu]
% sst =  table(:,14); % [C] or is it airTemp?
lat2 = table(:,16); % instrument in
lon2 = table(:,18);


%% Reconcile the two tables (Ship data and COPS log)

%Now assign the stations data. For each continuous ship reading,...
% 1. Find the nearest station timestamp within tLim
% 2. Confirm the location is within dLim
% 3. Confirm the ship is not moving more than sLim

for i=1:length(dateTime1)
    % dateTime3 can be hours apart
    [nearTime2, index] = find_nearest(dateTime1(i),dateTime2);
    % Within tLim min and stationary
    tDiff = abs(dateTime1(i) - nearTime2);
    if tDiff < datenum(0,0,0,0,tLim,0)
        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat2(index)); 
        dlon = kpdlon*(lon1(i) - lon2(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if dist < dLim
            if stw(i) < sLim
                % stn year month day hour minute sec lat lon(9) speed wind sst
                % sss(13) cloud(14) seas(15) dist(16) shipGyro(17) SASgyro(18),
                % relAz(19)
                newDataMat(i,1) = station(index);
                newDataMat(i,14) = cloud(index);
                newDataMat(i,15) = seas(index);
                newDataMat(i,16) = dist;
                fprintf('Match Station: %d\n', station(index))
            else
                fprintf('Station: %d, Too fast: %.1f\n', station(index), stw(i))
                newDataMat(i,1) = -9999;
                newDataMat(i,14) = -9999;
                newDataMat(i,15) = -9999;
                newDataMat(i,16) = -9999;
            end
        else
            fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
            newDataMat(i,1) = -9999;
            newDataMat(i,14) = -9999;
            newDataMat(i,15) = -9999;
            newDataMat(i,16) = -9999;
        end
    else
        fprintf('Station: %d, Too much time: %1.0f min\n', station(index),minutes(tDiff))
        newDataMat(i,1) = -9999;
        newDataMat(i,14) = -9999;
        newDataMat(i,15) = -9999;
        newDataMat(i,16) = -9999;
    end
end

%% HyperSAS field notes (viirs_2019_FSG_Stationlog.xlsx) worksheet 2
% for solAz, SASgyro, relAz
%   Every record needs a relAz. Pick the relAz from Scott's notes and
%   propagate forward in time until it changes

[table, ~] = xlsread(inFile2,'SAS'); %SAS metadata (Scott)

% Station start time does not contain date, but end time does. Can use the date
% from end time because these files never bridge GMT midnight
timeStart = table(:,2); % Begin SAS file fraction of day
dateTimeStop = table(:,3)+693960; % End SAS file datenum
dateTimeStart = datetime(floor(dateTimeStop) + timeStart, 'convertfrom','datenum');
dateTimeStop = datetime(dateTimeStop, 'convertfrom','datenum');

% Contains NaNs
% solAz = table(:,4); % ignore this - HySP will calculate SolAZ
SASgyro = table(:,5); % ship heading? from Scott's notes. Check this below
relAz = table(:,6); % SAS to ship heading

%% Remove met data from before and after the beginning and end of SAS files

junk = find(dateTime1 < dateTimeStart(1) | dateTime1 > dateTimeStop(end));
newDataMat(junk,:) = [];
dateTime1(junk) = [];

%% Reconcile the two tables

%Now assign the stations from KORUS_seabass_synthesis
% 1. Find records between SAS start and stop times
% 2. Add the SASgyro at start time
% 3. Add the relAz (SAS to ship) and propagate
% 4. No station information used here

for i=1:length(dateTimeStart)
    
    %     indexes = find(dateTime1 >= dateTimeStart(i) & dateTime1 <= dateTimeStop(i));
    
    % Here, we're just adding relaz and SASgyro, so need start time only. Just find the
    % nearest to the start time
    [~,indexAnc] = find_nearest(dateTimeStart(i), dateTime1);
    
    %      newDataMat(indexes,18) = repmat(solAz(i),1,length(indexes));
    
    % stn year month day hour minute sec lat lon(9) speed wind sst
    % sss(13) cloud(14) seas(15) dist(16) shipGyro(17) SASgyro(18),
    % relAz(19)
    % For comparison with ship data...
    newDataMat(indexAnc,18) = SASgyro(i); % Don't propagate this; it's static
    
    % Relative azimuth must be propagated forward until the next change is
    % noted in the log. All records must have relAz
    %     newDataMat(indexes,16) = repmat(relAz(i),1,length(indexes));
    nRecs = size(newDataMat,1) - indexAnc +1;
    newDataMat(indexAnc:end,19) = repmat(relAz(i),1,nRecs);
end

% Plot the comparison to Scott's notes for ship heading and the actual ship
% heading
newDataMat(newDataMat == -9999) = nan;
plot(newDataMat(:,17),newDataMat(:,18),'.')
p11
xlabel('Met file (Ship Gyro Heading)')
ylabel('SAS file (Ship Gyro Heading??)')
print plt/VIIRS2019_Heading -dpng

% The agreement between Scott's noted ship heading and the ship file is
% poor. Eliminate the SASgyro from the record
% stn year month day hour minute sec lat lon(9) speed wind sst
% sss(13) cloud(14) seas(15) dist(16) shipGyro(17) SASgyro(18) relAz(19)
newDataMat(:,18) = [];
% sss(13) cloud(14) seas(15) dist(16) shipGyro(17) relAz(18)

%Eliminate distance for ease of writing the file below
newDataMat(:,16) = [];
% stn year month day hour minute sec lat lon(9) speed wind sst
% sss(13) cloud(14) seas(15) shipGyro(16) relAz(17)

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
% stn year month day hour minute sec lat lon(9) speed wind sst
% sss(13) cloud(14) seas(15) shipGyro(16) relAz(17)

for i=1:size(newDataMat,1)
                  % sta year mon day hour min sec lat lon stw windSp sst sss cloud seas heading relAz
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%.1f,%.1f,%d,%.1f,%03.0f,%03.0f\n',...
        newDataMat(i,:));
end

fclose(fidOut);