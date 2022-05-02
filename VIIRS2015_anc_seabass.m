
% Read in ship and log data and output SeaBASS formatted data

wipe

datDir = '~/Projects_Supplemental/HyperPACE/field_data/metadata/VIIRS2015/';

% Ship file converted from SCS using Compactor2.0
inFile = [ datDir 'SCS_Compaction_VIIRS2015.csv'];
inFile2 = [datDir 'VIIRS_2015_NasaStationlog.xlsx'];
outFile = [datDir 'VIIRS2015_Ancillary.sb'];
inHeader = [datDir 'VIIRS2015_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Ship data

table = readtable(inFile);
dateTimeCell = table{:,1};

%%%%%%%%%%%%Beware of SAMOS Lat/Lon, at only two decimal places, it is only
%%%%%%%%%%%%accurate to about 1.1 km or more, Compactor the GPS Lat/Lon
%%%%%%%%%%%%(not SAMOS)
% lat1 = table{:,2};
% lon1 = table{:,3};
table(:,4:5) = []; % Delete SAMOS LatLon
lat = table{:,2};
lon = table{:,3};
cog = table{:,4};
sog = table{:,5};
gyro = table{:,6};
airTemp = table{:,7};
% relH = table{:,8}; No seabass field for humidity
sst = table{:,9};
%baro
windSpeed = table{:,11};% m/s
windDir = table{:,12}; % degrees
sss = table{:,14};

% % Format an array
% sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst sss gyro cloud seas
newDataMat = NaN(numel(dateTimeCell),19);
lat1 = NaN(numel(dateTimeCell),1);
lon1 = lat1;
dateTime1 = NaT(numel(dateTimeCell),1);

% With GPS3, data is at 2 second resolution. Subsample every 30 rows to get
% about 2 per minute.
subSamp = 0;

for i=1:numel(dateTimeCell)
    subSamp = subSamp +1;
    if subSamp >= 60
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
            newDataMat(i,:) = [-9999, year, month, day, hour, minute, second, lat1(i), lon1(i), ...
                sog(i), cog(i), windSpeed(i), windDir(i), airTemp(i), sst(i), sss(i), gyro(i), -9999, -9999];
            subSamp = 0;
        catch
            disp('Error reading from Compaction table.')
        end
    end
end

test = newDataMat(:,1);
noData = isnan(test);
newDataMat(noData,:) = [];
dateTime1(noData) = []; lat1(noData) = []; lon1(noData) = []; sog(noData) = [];
clear latDD latMM lonDD lonMM year month day hour minute second subSamp table dateTimeCell
clear lat lon cog windSpeed windDir airTemp sst sss test noData
disp('Compaction table complete')

%% COPS station log

[table, txt] = xlsread(inFile2,'cops'); %COPS metadata (Scott)
table(75:end,:) = []; % Don't know what this repeat table is

dateTime2 = table(:,2)+693960; % Begin COPS datetime
dateTime2 = datetime(dateTime2,'convertfrom','datenum');
station = table(:,5);
lat2 = table(:,6);
lon2 = table(:,7);
% Use the true wind readings from the ship instead, not these.
windSpeed = table(:,10);% m/s
windDir = table(:,11); % degrees

cloud = table(:,9); % percent
seas = table(:,12); % m

%% Reconcile the two tables

%Now assign the stations
% 1. Find the nearest station timestamp within 30 min
% 2. Confirm the location is within 1.5 km
% 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)
%           Gulf Stream could be reason for Too Fast station 19 - 22
%                       Use 2.5 kts (1.29 m/s)
%               Also expand distance for the same reason to 2.0 km            

for i=1:length(dateTime1)
    [near_scalar, index] = find_nearest(dateTime1(i),dateTime2);
    % Within 30 min and stationary
    if abs(dateTime1(i) - dateTime2(index)) < minutes(30)

        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat2(index)); 
        dlon = kpdlon*(lon1(i) - lon2(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if station(index) >= 19 && station(index) <= 23
            distLim = 2.0;
            sogLim = 2.5;
        else
            distLim = 1.5;
            sogLim = 1.3; % adjusted up for near-Gulf Stream stations
        end
        
        if dist < distLim
            if sog(i) < sogLim
                % sta year mon day hour min sec lat lon sog cog windSp 
                % windDir airTemp sst sss cloud seas dist
                newDataMat(i,1) = station(index);
                newDataMat(i,18) = cloud(index);
                newDataMat(i,19) = seas(index);
%                 newDataMat(i,19) = dist;
            else
                fprintf('Station: %d, Too fast\n', station(index))
                newDataMat(i,1) = -9999;
                newDataMat(i,18) = -9999;
                newDataMat(i,19) = -9999;
%                 newDataMat(i,19) = -9999;
            end
        else
            fprintf('Station: %d, Too far: %.3f\n', station(index), dist)
            newDataMat(i,1) = -9999;
            newDataMat(i,18) = -9999;
            newDataMat(i,19) = -9999;
%             newDataMat(i,19) = -9999;
        end
    else
        %         disp('Too much time gap')
        newDataMat(i,1) = -9999;
        newDataMat(i,18) = -9999;
        newDataMat(i,19) = -9999;
%         newDataMat(i,19) = -9999;
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
% sta year mon day hour min sec lat lon sog cog windSp 
                % windDir airTemp sst sss cloud seas dist

for i=1:size(newDataMat,1)
                   % sta year mon day hour min sec lat lon sog windSp windDir airTemp sst sss gyro cloud seas
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.2f,%03.0f,%.1f,%0.1f,%03.0f,%0.2f,%d,%0.1f\n',...
        newDataMat(i,[1:10, 12:18]));
end

fclose(fidOut);




    
    
