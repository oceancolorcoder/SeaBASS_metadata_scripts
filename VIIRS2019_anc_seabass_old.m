wipe

% Read in Excel data and output SeaBASS formatted data

tLim = 30; % minutes
dLim = 1.5; % km
sLim = 1.0; % m/s ~= 2.0 kts

datDir = '~/Projects_Supplemental/HyperPACE/field_data/metadata/VIIRS2019/';

% Samos files are broken into 
inFile = [datDir 'Ship_Data/GU19_03_Samos/SAMOS-OBS_merged.xlsx'];

% Contains COPS station info and SAS pointing info
% SolarTracker broken, turned by hand and recorded in logs
inFile2 = [datDir 'viirs_2019_FSG_Stationlog.xlsx']; 

outFile = [datDir 'VIIRS2019_Ancillary.sb'];
inHeader = [datDir 'VIIRS2019_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Ship data

[table, ~] = xlsread(inFile);
% https://www.mathworks.com/help/exlink/convert-dates-between-microsoft-excel-and-matlab.html
%To use date numbers in MATLAB calculations, apply the 693960 constant as follows:
%     Add it to Excel date numbers that are read into the MATLAB software.
%     If you use the optional Excel 1904 date system, the constant is 695422.
dateTime1 = table(:,1)+table(:,2)+693960;
lat1 = table(:,4);
lon1 = table(:,5);
airT = table(:,6);
baro = table(:,7);
heading = table(:,8);
rh = table(:,9);
windDir = table(:,12);
windSpeed = table(:,13);
sss = table(:,15);
cog = table(:,16);
sog = table(:,17);
sst = table(:,18);

% % Format an array
% sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst
% sss cloud seas dist solAz gyro relAz heading
newDataMat = nan*ones(size(dateTime1,1),23);

for i=1:length(dateTime1)
    [year, mon, day, hr, minute, sec] = datevec(dateTime1(i));
    newDataMat(i,:) = [-9999, year, mon, day, hr, minute, sec, lat1(i), lon1(i), ...
        sog(i), cog(i), windSpeed(i), windDir(i), airT(i), sst(i), sss(i), ...
        -9999, -9999, -9999, -9999, -9999, -9999, heading(i)];
end

%% COPS station log

[table, txt] = xlsread(inFile2,'C-Ops'); %COPS metadata (Scott)
txt(1:10,:) = [];

dateTime2 = table(:,4)+693960; % Begin COPS datetime
station = str2double(txt(:,6));
wDepth = table(:,7); % [m]
cloud = table(:,8); % %
seas = table(:,9);
windSpeed = table(:,11);% m/s
windDir = table(:,12); % degrees
sss = table(:,13);
sst =  table(:,14); % or is it airTemp?

lat2 = table(:,16); % instrument in
lon2 = table(:,18);


%% Reconcile the two tables

%Now assign the stations data. For each continuous ship reading,...
% 1. Find the nearest station timestamp within 45 min
% 2. Confirm the location is within 1.0 km
% 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)

for i=1:length(dateTime1)
    % dateTime3 can be hours apart
    [near_scalar, index] = find_nearest(dateTime1(i),dateTime2);
    % Within tLim min and stationary
    if abs(dateTime1(i) - dateTime2(index)) < datenum(0,0,0,0,tLim,0)
        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat2(index)); 
        dlon = kpdlon*(lon1(i) - lon2(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if dist < dLim
            if sog(i) < sLim
                % sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst
                % sss cloud seas dist solAz gyro relAz heading
                newDataMat(i,1) = station(index);
                newDataMat(i,17) = cloud(index);
                newDataMat(i,18) = seas(index);
                newDataMat(i,19) = dist;
            else
                fprintf('Station: %d, Too fast: %.1f\n', station(index), sog(i))
                newDataMat(i,1) = -9999;
                newDataMat(i,17) = -9999;
                newDataMat(i,18) = -9999;
                newDataMat(i,19) = -9999;
            end
        else
            fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
            newDataMat(i,1) = -9999;
            newDataMat(i,17) = -9999;
            newDataMat(i,18) = -9999;
            newDataMat(i,19) = -9999;
        end
    else
        %         disp('Too much time gap')
        newDataMat(i,1) = -9999;
        newDataMat(i,17) = -9999;
        newDataMat(i,18) = -9999;
        newDataMat(i,19) = -9999;
    end
end

%% HyperSAS 

[table, ~] = xlsread(inFile2,'SAS'); %SAS metadata (Scott)

% Start time does not contain date, but end time does. Can use the date
% from end time because these files never bridge midnight
timeStart = table(:,2); % Begin SAS file fraction of day
dateTimeStop = table(:,3)+693960; % End SAS file datetime
dateTimeStart = floor(dateTimeStop) + timeStart;

% Contains NaNs
solAz = table(:,4);
gyro = table(:,5); % ship heading?
relAz = table(:,6); % SAS to ship heading

%% Remove met data from before and after the beginning and end of SAS files

junk = find(dateTime1 < dateTimeStart(1) | dateTime1 > dateTimeStop(end));
newDataMat(junk,:) = [];
dateTime1(junk) = [];

%% Reconcile the two tables

%Now assign the stations from KORUS_seabass_synthesis
% 1. Find records between SAS start and stop times

for i=1:length(dateTimeStart)
    
    indexes = find(dateTime1 >= dateTimeStart(i) & dateTime1 <= dateTimeStop(i));
        
    % sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst
    % sss cloud seas dist solAz gyro relAz heading
    newDataMat(indexes,20) = repmat(solAz(i),1,length(indexes));
    newDataMat(indexes,21) = repmat(gyro(i),1,length(indexes));
    newDataMat(indexes,22) = repmat(relAz(i),1,length(indexes));
end

newDataMat(newDataMat == -9999) = nan;
% plot(newDataMat(:,23),newDataMat(:,21),'.')
% p11
% xlabel('Met file (Heading)')
% ylabel('SAS file (Gyro)')
% print plt/VIIRS2019_Heading -dpng

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
% sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst
% sss cloud seas dist solAz gyro relAz heading

for i=1:size(newDataMat,1)
                  % sta year mon day hour min sec lat lon sog windSp windDir airTemp sst sss cloud seas relAz heading
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%03.0f,%.1f,%.1f,%.1f,%d,%.1f,%03.0f,%03.0f\n',...
        newDataMat(i,[1:10, 12:18, 22:23]));
end

fclose(fidOut);