wipe

tLim = 15; % minutes (ship data interpolate from 10 to 5 minutes
dLim = 1; % km for stations.
sLim = 0.9; % m/s ~= 1.75 kt for stations       SOG this cruise
SZALim = 72; % degrees for screening out night (see sun_position below)

datDir = '~/Projects/HyperPACE/field_data/metadata/EKAMSAT_2024/';

% %% Ship data courtesy of Leah Johnson (UW), Amit Tandon (UMass), Elizabeth Thompson (NOAA)
%   Only 10 minute resolution available for these dates
%   Interpolate to 5 min
inFile1 = [datDir 'Processed/ASTRAL-nav-met-sea-flux-10min_RV-Thompson_20240428_R1_thru_20240513.nc']; % contains full cruise

% Scott's field notes (no radiometry field log provided)
inFile2 = [datDir 'station_notes.xlsx'];

outFile = [datDir 'EKAMSAT_2024_Ancillary.sb'];
inHeader = [datDir 'EKAMSAT_2024_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

% Truncate
startDT = datetime(2024,5,2,3,50,00,'TimeZone','UTC'); % First pySAS raw file
endDT = datetime(2024,5,13,3,10,00,'TimeZone','UTC'); % Last pySAS raw file


%% Ship data

time = ncread(inFile1,'time'); % seconds since 2024-01-01 00:00:00 UTC
dateTime1 = datetime((datetime('2024-01-01 00:00:00','TimeZone','UTC') + seconds(time)),'TimeZone','UTC');

% Truncate to this cruise
gud = (dateTime1 >= startDT & dateTime1 <= endDT);
dateTime1 = dateTime1(gud);

lat = ncread(inFile1,'lat');
lon = ncread(inFile1,'lon');
sog = ncread(inFile1,'sog');
wind = ncread(inFile1,'wspd_10'); % 10 m true
sst = ncread(inFile1,'tsea_ship');
sal = ncread(inFile1,'ssea_ship');
heading = ncread(inFile1,'heading');

% % Format an array
% sta year mon day hour min sec lat lon(9) SOG windSp sst sss(13) cloud seas(15) heading
newDataMat = NaN(length(dateTime1),16);

newDataMat(:,2) = year(dateTime1);
newDataMat(:,3) = month(dateTime1);
newDataMat(:,4) = day(dateTime1);
newDataMat(:,5) = hour(dateTime1);
newDataMat(:,6) = minute(dateTime1);
newDataMat(:,7) = second(dateTime1);
newDataMat(:,8) = lat(gud);
newDataMat(:,9) = lon(gud);
newDataMat(:,10) = sog(gud);
newDataMat(:,11) = wind(gud);
newDataMat(:,12) = sst(gud);
newDataMat(:,13) = sal(gud);
newDataMat(:,16) = heading(gud);

% Interpolate to 5 min
startTime = dateTime1(1);
endTime = dateTime1(end);
interTime = startTime:minutes(5):endTime;
newDataMat = interp1(dateTime1,newDataMat,interTime);
dateTime1 = interTime;

newDataMat(:,2) = year(dateTime1);
newDataMat(:,3) = month(dateTime1);
newDataMat(:,4) = day(dateTime1);
newDataMat(:,5) = hour(dateTime1);
newDataMat(:,6) = minute(dateTime1);
newDataMat(:,7) = floor(second(dateTime1)); % all zeros

sog = newDataMat(:,10);


%% Scott's notes

[table, txt] = xlsread(inFile2,'AOP');

% Use HyperPro filenames for station times
hproFiles = txt(2:19,3);
for i=1:length(hproFiles)
    if i==1
        % No Hpro (or pySAS) station 1
        yearDatetime(i) = datetime(2024,4,29,0,0,0,'TimeZone','UTC');
        hr(i) = 7;
        mn(i) = 15;
        sec(i) = 0;
    else
        txt = strrep(hproFiles{i},'.raw','');
        yr = str2double(txt(2:5));
        doty = str2double(txt(7:9));
        hr(i) = str2double(txt(11:12));
        mn(i) = str2double(txt(13:14));
        sec(i) = str2double(txt(15:16));

        yearDatetime(i) = datetime(yearday([yr doty]),'TimeZone','UTC','ConvertFrom','datenum');
    end
end

dateTime2 = datetime(year(yearDatetime), month(yearDatetime), day(yearDatetime),hr,mn,sec,'TimeZone','UTC');

station = table(:,1);
cloud = table(:,9); % [%]
seas = table(:,11); % [m]

%% Reconcile the two tables (Ship data and field log)

% Now assign the stations data. For each continuous ship reading,...
% 1. Find the nearest station timestamp within tLim
% 2. Confirm the location is within dLim                (no lat lon in field logs this cruise)
% 3. Confirm the ship is not moving more than sLim

for i=1:length(dateTime1)

    [nearTime2, index] = find_nearest(dateTime1(i),dateTime2);
    % Within tLim min and stationary
    tDiff = abs(dateTime1(i) - nearTime2);
    if tDiff <= minutes(tLim)

        % kpdlon = kpdlat*cos(pi*lat1(i)/180);
        % dlat = kpdlat*(lat1(i) - lat2(index));
        % dlon = kpdlon*(lon1(i) - lon2(index));
        % dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]

        % if dist < dLim || isnan(dist)
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
        % else
        %     fprintf('Station: %d, Too far: %.1f\n', station(index),dist)
        %     newDataMat(i,1) = -9999;
        %     newDataMat(i,14) = -9999;
        %     newDataMat(i,15) = -9999;
        %     %             newDataMat(i,16) = -9999;
        %     % end
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
% stn year month day hour minute sec lat lon(9) SOG wind sst sss(13) cloud(14) seas(15) heading
%
%   SOG is not permissible in SeaBASS
sog = newDataMat(:,10);
newDataMat(:,10) = [];

for i=1:size(newDataMat,1)
    % sta year mon day hour min sec lat lon wind sst sss cloud seas heading
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.2f,%.2f,%.1f,%.1f,%.1f\n',...
        newDataMat(i,:));
end

fclose(fidOut);

%%
newDataMat(newDataMat==-9999) = nan;
dateTime = interTime;

% yyaxis("left")
plot(dateTime,sog,'.')
% yyaxis("right")
hold on
plot(dateTime2,station*0,'.','MarkerSize',18,'Color','r')
grid
