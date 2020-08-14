% Read in Excel data and output SeaBASS formatted data

% datDir = 'Field_Data/KORUS/Cruise_Logs/';
datDir = './';

% Custom formatted Excel file
inFile = [datDir 'KORUS_Onnuri_Location_AWS_noblanks.xlsx'];
inFile2 = [datDir 'KORUS_flow_thru.xlsx'];
inFile3 = [datDir 'KORUS_seabass_synthesis.xlsx'];
outFile = [datDir 'KORUS_Ancillary.sb'];
inHeader = [datDir 'KORUS_Ancillary_header1.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Ship data
[table, ~] = xlsread(inFile);
lat = table(:,3);
lon = table(:,4);
badIndex = 0*ones(1,length(lat));
for i=1:length(lat)
    if isnan(lat(i)) || isnan(lon(i)) || lat(i)==-9999 || lon(i)==-9999
        badIndex(i) = 1;
    end
end
table(logical(badIndex),:) = [];

% xDatetime = table(:,2);
% https://www.mathworks.com/help/exlink/convert-dates-between-microsoft-excel-and-matlab.html
%To use date numbers in MATLAB calculations, apply the 693960 constant as follows:
%     Add it to Excel date numbers that are read into the MATLAB software.
%     If you use the optional Excel 1904 date system, the constant is 695422.
dateTime = table(:,2)+693960;
lat = table(:,3);
lon = table(:,4);
windSpeed = table(:,5);
windDir = table(:,6);
temp = table(:,7);
relHum =  table(:,8);
speed = table(:,16); % m/s
% There's more in there... skip it for now

% Format an array
dataMat = nan*ones(length(dateTime),13);
for i=1:length(dateTime)
    [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
    dataMat(i,:) = [year, mon, day, hr, minute, sec, lat(i), lon(i), ...
        windSpeed(i), windDir(i), temp(i), speed(i), relHum(i) ];
end
dataMat(isnan(dataMat)) = -9999;

% Relative Humidity is currently not a SB field
dataMat(:,end) = [];

%% Flow thru data
[table, ~] = xlsread(inFile2);
lat2 = table(:,7);
lon2 = table(:,8);
badIndex = 0*ones(1,length(lat2));
for i=1:length(lat2)
    if isnan(lat2(i)) || isnan(lon2(i)) || lat2(i)==-9999 || lon2(i)==-9999
        badIndex(i) = 1;
    end
end
table(logical(badIndex),:) = [];

year = table(:,1);
month = table(:,2);
day = table(:,3);
hour = table(:,4);
minute = table(:,5);
second = table(:,6);
dateTime2 = datenum(year,month, day, hour, minute, second);
% dateTime = table(:,2)+693962;
Wt = table(:,11);
sal = table(:,13);
speed = table(:,10);

% Format an array
dataMat2 = nan*ones(length(year),4);
for i=1:length(year)
%     [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
    dataMat2(i,:) = [ dateTime2(i),...
        Wt(i), sal(i), speed(i)];
end
dataMat2(isnan(dataMat2)) = -9999;

%% Station data
[table, xHead] = xlsread(inFile3, 'cdom_flag');
lat3 = table(:,7);
lon3 = table(:,8);
badIndex = 0*ones(1,length(lat3));
for i=1:length(lat3)
    if isnan(lat3(i)) || isnan(lon3(i)) || lat3(i)==-9999 || lon3(i)==-9999
        badIndex(i) = 1;
    end
end
table(logical(badIndex),:) = [];

yeardate = table(:,1);
time = xHead(38:end,2);
station = table(:,3);
depth = table(:,4);
alt = xHead(38:end,6);
lat3 = table(:,7);
lon3 = table(:,8);


% Exclude stations at depth and JangMok stations
% Timestamps are repeated in spreadsheet for stations at depth
deep = find(depth >= 5);
yeardate(deep) = [];
station(deep) = [];
time(deep) = [];
alt(deep) = [];
lat3(deep) = [];
lon3(deep) = [];

jangMok = find(alt == "JangMok");
yeardate(jangMok) = [];
station(jangMok) = [];
time(jangMok) = [];
lat3(jangMok) = [];
lon3(jangMok) = [];

% Don't need more than one station per station
[C, ia, ic] = unique(station);
yeardate = yeardate(ia);
station = station(ia);
time = time(ia);
lat3 = lat3(ia);
lon3 = lon3(ia);

% Format an array
dataMat3 = nan*ones(length(yeardate),4);
dateTime3 = nan*ones(length(yeardate),1);
for i=1:length(yeardate)
	ydStr = num2str(yeardate(i));
    year = str2double(ydStr(1:4));
    month = str2double(ydStr(5:6));
    day = str2double(ydStr(7:8));
    timeStr = replace(time{i},"'",'');
    hour = str2double(timeStr(1:2));
    minute = str2double(timeStr(4:5));
    second = str2double(timeStr(7:8));
    dateTime3(i) = datenum(year, month, day, hour, minute, second);
    dataMat3(i,:) = [ dateTime3(i), station(i), lat3(i), lon3(i) ];
end
dataMat3(isnan(dataMat3)) = -9999;


%% Reconcile and combine the third table (station)
% datestr(min(dateTime))
% datestr(max(dateTime))
% datestr(min(dateTime2))
% datestr(max(dateTime2))
% Use file 1 as basis

% sta year mon day hour min sec lat lon windSp windDir temp wT sal speed1 speed2 dist
newDataMat = nan*ones(size(dataMat,1),17);

for i=1:length(dateTime)
    [near_scalar, index] = find_nearest(dateTime(i),dateTime2);
    [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
    % dateTime collected every minute, dateTime2 every 20 sec
    if abs(dateTime(i) - dateTime2(index)) < datenum(0,0,0,0,1,0) % within 1 minute        
        newDataMat(i,:) = [nan, year, mon, day, hr, minute, sec, lat(i), lon(i), ...
            dataMat(i,9), dataMat(i,10), dataMat(i,11), ...
            dataMat2(index,2), dataMat2(index,3), dataMat(i,12), dataMat2(index,4), -9999];
    else
%         disp('Too much time gap')
        newDataMat(i,:) = [nan, year, mon, day, hr, minute, sec, lat(i), lon(i), ...
            dataMat(i,9), dataMat(i,10), dataMat(i,11), ...
            -9999, -9999, dataMat(i,12), -9999, -9999];
    end
end
speed1 = newDataMat(:,15);
speed2 = newDataMat(:,16);
speed1(speed1==-9999 | speed1 > 15) = nan;
speed2(speed2==-9999 | speed2 > 15) = nan;
plot(speed1,speed2,'.')
xlabel('KORUS\_Onnuri\_Location\_AWS.xlsx; Speed of the vessel (m/s)')
ylabel('KORUS\_flow\_thru.xlsx; speed\_f\_w [m/s]')
print speeds -dpng
% speed1 = newDataMat(:,15);
% speed2 = newDataMat(:,16);

% Now assign the stations from KORUS_seabass_synthesis
% 1. Find the nearest station timestamp within 30 min
% 2. Confirm the location is within 1.0 km
% 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)
for i=1:length(dateTime)
    % dateTime3 can be hours apart
    [near_scalar, index] = find_nearest(dateTime(i),dateTime3);
    % Within 30 min and stationary
    if abs(dateTime(i) - dateTime3(index)) < datenum(0,0,0,0,30,0)
        lat1 = newDataMat(i,8);
        lon1 = newDataMat(i,9);
        kpdlon = kpdlat*cos(pi*lat1/180);
        dlat = kpdlat*(lat1 - lat3(index)); 
        dlon = kpdlon*(lon1 - lon3(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if dist < 1.0
            if ((speed1(i) < 0.77) || isnan(speed1(i))) && ...
                    ((speed2(i) < 0.77) || isnan(speed2(i))) && ...
                    ~( isnan(speed1(i)) && isnan(speed2(i)) )
                newDataMat(i,1) = station(index);
                newDataMat(i,17) = dist;
            else
                disp('Too fast')
                newDataMat(i,1) = -9999;
            end
        else
            disp('Too far')
            newDataMat(i,1) = -9999;
        end
    else
%         disp('Too much time gap')
        newDataMat(i,1) = -9999;
    end
end
    



fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');

line = '';
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);

% sta year mon day hour min sec lat lon windSp windDir temp wT sal speed1 speed2 dist
newDataMat(:,15) = nanmean([speed1 speed2]')';
newDataMat(isnan(newDataMat(:,15)),15) = -9999;
newDataMat(:,16:17) = [];



for i=1:size(newDataMat,1)
                    % sta year mon day hour min sec lat lon windSp windDir temp wT sal speed
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%03.0f,%.2f,%.4f,%.4f,%.4f\n',newDataMat(i,:));
end

fclose(fidOut);
    
    
