% Read in Excel data and output SeaBASS formatted data

datDir = '~/Projects/HyperPACE/field_data/metadata/EXPORTS/';
inFile1 = [datDir 'exports_2018_FSG_Stationlog_clean.xlsx']; % IOP_Cage: wind, cloud, seas, has just a few readings per day
                                                            % SAS: sensor geometry after tracker broke
inFile2 = [datDir 'R2R_ELOG_SR1812_FINAL_EVENTLOG_20180913_022931_clean.xlsx']; %R2R Event log, includes time, lat/lon, event name, station name
inFile3 = [datDir 'SR1812_uwmet_v1.csv']; % Comprehensive ship readings including heading, sst, sss, wind, etc. every few seconds


outFile = [datDir 'EXPORTS_Ancillary.sb'];
inHeader = [datDir 'EXPORTS_Ancillary_header1.sb'];

kpdlat = 111.325; %km per deg. latitude

%% inFile1: exports_2018_FSG_Stationlog_clean
fprintf('Read File 1; IOP Cage: %s\n',inFile1)
% time lat lon cloud seas
[data1, header1] = xlsread(inFile1,'IOP cage');
lat1 = data1(:,9);
lon1 = data1(:,12);

dateTime1 = datenum2datetime(datenum(2018,0,data1(:,6)));
% windSpeed1 = data1(:,14);
% windDir1 = data1(:,15);
cloud1 = data1(:,13);
seas1 = data1(:,16);

% Import SAS sheet exports_2018_FSG_Stationlog_clean
% time offset
fprintf('Read File 1; SAS: %s\n',inFile1)
[data2, ~] = xlsread(inFile1,'SAS');
sTime = datetime(data2(:,2),'convertfrom','excel'); % incomplete format
dateTime1s = NaT(1,length(sTime)); % Not a Time...
for i=1:length(sTime)
    yeardate = num2str(data2(i,1)); % grab date from first column
    year = str2double(yeardate(1:4));
    mon = str2double(yeardate(5:6));
    day = str2double(yeardate(7:8));
    [hh,mm,ss] = hms(sTime(i));
    dateTime1s(i) = datetime(year, mon, day, hh, mm, ss);
end
dateTime1e = datetime(data2(:,3),'convertfrom','excel');
offset = data2(:,6); % SAS relative to ship
clear data2 header2

%% inFile2: R2R_ELOG_SR1812_FINAL_EVENTLOG
% R2R_Event is a valid seabass field

fprintf('Read File 2: %s\n',inFile2)
% lat lon R2R station
[data2, header2] = xlsread(inFile2);
lat2 = data2(:,9);
lon2 = data2(:,10);
% r2rEvent = header2(2:end,15);
% Highly problematic. Repeat station names have different locations...
% Apparently from different Epochs?
% LS (Large ship survey); SS (Small ship survey); ES (Extended survey)
% Epoch/survey; often an empty field, but sequential, so it could be filled
% in...
% Another major issue: The timestamps are not necessarily when an event
% occurred, but rather when it was LOGGED. And only some people logged the
% station names of any kind, and the varied in how they typed it in.
% THIS IS A FUCKING UNHOLY MESS!!

% epochS = header2(2:end,6);
stationS = header2(2:end,7);
dateStr = header2(2:end,18);

dateTime2 = NaT(1,length(dateStr)); % NaT: Not a Time...
for i=1:length(dateStr)
    line = dateStr{i};
    year = str2double(line(1:4));
    mon = str2double(line(6:7));
    day = str2double(line(9:10));
    hh = str2double(line(12:13));
    mm = str2double(line(15:16));
    ss = str2double(line(18:19));
    if ~isnan(year)
        dateTime2(i) = datetime(year, mon, day, hh, mm, ss);
    end
end

% Blow away rows where the station is NaN to avoid misdirection to
% unlabelled stations
badIndex = find(contains(stationS,'NaN'));
stationS(badIndex) = [];
dateTime2(badIndex) = [];
lat2(badIndex) = [];
lon2(badIndex) = [];
badIndex = find(cellfun('isempty',stationS));
stationS(badIndex) = [];
dateTime2(badIndex) = [];
lat2(badIndex) = [];
lon2(badIndex) = [];

%% inFile3: SR1812_uwmet_v1.csv (most complete data file)

fprintf('Read File 3: %s\n',inFile3)
% frequency ~ 30 seconds
% time lat lon COG SOG heading Wt sal wind wdir
data3 = readmatrix(inFile3, 'NumHeaderLines', 4, 'TreatAsMissing', '-99');

%% Walk through this more complete dataset, and tack on cloud, seas
% 1. Find the nearest station timestamp within 30 min
% 2. Confirm the location is within 1.0 km
% 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)

% fill with nans otherwise
% Use find_nearest, but not to exceed 10 minutes
dataMat = NaN(length(data3),18);

tLim = minutes(60); % had to open this up to 1 hour to pick up more labelled stations in the R2R file
dLim = 1; % km
sLim = 0.77; % m/s (1.5 kts)
disp('Looping')
for i=1:length(data3)
    dateTime3 = datetime(data3(i,1), data3(i,2), data3(i,3), data3(i,4), data3(i,5), data3(i,6));
    SOG = data3(i,11);
    lat3 = data3(i,8);
    lon3 = data3(i,9);
    
    % /fields=station,year,month,day,hour,minute,second,lat,lo,SOG,heading,Wt,sal,
    %   wind,wdir,cloud,waveht,offset
    dataMat(i,2:15) = [data3(i,1), data3(i,2), data3(i,3), data3(i,4), data3(i,5), data3(i,6), ...
        lat3, lon3, ...
        SOG, data3(i,12), data3(i,13), data3(i,14), ...
        data3(i,29), data3(i,30)];
    
    [near_time, index] = find_nearest(dateTime3,dateTime1);
    if (dateTime3 > near_time-tLim) && (dateTime3 < near_time+tLim)
        %         dataMat(i,12) = windSpeed1(index);
        %         dataMat(i,13) = windDir1(index);
        dataMat(i,16) = cloud1(index);
        dataMat(i,17) = seas1(index);
    end
    
    [near_time, index] = find_nearest(dateTime3,dateTime1s);
    if (dateTime3 >= near_time-tLim) && (dateTime3 < near_time+tLim)
        dataMat(i,18) = offset(index);
    end
    
    [near_time, index] = find_nearest(dateTime3,dateTime2);
    if (dateTime3 >= near_time-tLim) && (dateTime3 < near_time+tLim)
        kpdlon = kpdlat*cos(pi*lat3/180);
        dlat = kpdlat*(lat3 - lat2(index));
        dlon = kpdlon*(lon3 - lon2(index));
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        if dist < dLim && SOG < sLim
            % unique(stationS)
            % Here we have either NaN or cell strings, need to reassign
            % values to be doubles to put into dataMat as well as the HDF5
            % data later in HyperInSPACE. For the purposes of EXPORTS, we
            % have 143 unique "station" names, but many of them have
            % nothing to do with actual cruise stations. SS is small scale
            % survey, LS is large scale, ES is extended survey, and I don't
            % know what the rest is. They are all entered slightly
            % differently (i.e. some have blank space, etc., but aside from
            % the letter designiation, they appear to all be integers.
            % Therefore, we can use decimals to represent the various
            % survey designations, as follows:
            
            %   +0.1: SS, +0.2: LS, +0.3: ES
            stationString = stationS{index};
            stationString(stationString == ' ') = [];
            if length(stationString) > 2
                if strcmp(stationString(1:2),'SS')
                    dataMat(i,1) = str2double(stationString(3:end)) + 0.1;
                elseif strcmp(stationString(1:2),'LS')
                    dataMat(i,1) = str2double(stationString(3:end)) + 0.2;
                elseif strcmp(stationString(1:2),'ES')
                    dataMat(i,1) = str2double(stationString(3:end)) + 0.3;
                end
            end
            
            
            
            %             dataMat(i,1) = stationS(index);
        end
    end
end
dataMat(isnan(dataMat)) = -9999;


%% Transcribe the sb header and write file
fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');
line = '';


disp('Outputing seabass file')
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);
% fprintf(fidOut,'%s\n','/end_header\n');

for i=1:size(dataMat,1)
    %     fprintf(fidOut,'%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%3.0f,%.2f,%.2f\n',dataMat(i,:));
    % station,year,month,day,hour,minute,second,lat,lon,SOG,heading,Wt,sal,wind,wdir,cloud,waveht,offset
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%03.0f,%.2f,%.2f,%.1f,%03.0f,%.0f,%.2f,%.1f\n',dataMat(i,:));
end

fclose(fidOut);


