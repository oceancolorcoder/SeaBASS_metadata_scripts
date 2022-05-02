% Read in Excel data and output SeaBASS formatted data

datDir = '~/Projects_Supplemental/HyperPACE/field_data/metadata/VIIRS2014/';

% Ship file converted from .elg(CSV) to .xlsx
inFile = [ datDir 'SAMOS-OBS_001.xlsx'];
inFile2 = [datDir 'VIIRS_NasaStationlog.xlsx'];
outFile = [datDir 'VIIRS2014_Ancillary.sb'];
inHeader = [datDir 'VIIRS2014_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Ship data

[table, txt] = xlsread(inFile);
% https://www.mathworks.com/help/exlink/convert-dates-between-microsoft-excel-and-matlab.html
%To use date numbers in MATLAB calculations, apply the 693960 constant as follows:
%     Add it to Excel date numbers that are read into the MATLAB software.
%     If you use the optional Excel 1904 date system, the constant is 695422.
dateTime1 = table(:,1)+table(:,2)+693960;
lat1 = table(:,3);
lon1 = table(:,4);
sog = table(:,5);
cog = table(:,6);
% There are two windexes: RWIND and TWIND. I don't know what these
% represent, but they agree fairly closely in wind speed (R is a bit
% higher), and not at all in wind direction. Must be true versus
% relative...
windSpeed = table(:,12);% m/s
windDir = table(:,13); % degrees
sst = table(:,14);
temp = table(:,8);
% Table also has RH, and Baro...

% % Format an array
% sta year mon day hour min sec lat lon sog cog windSp windDir airTemp sst sss cloud seas dist
newDataMat = nan*ones(size(dateTime,1),19);

for i=1:length(dateTime1)
    [year, mon, day, hr, minute, sec] = datevec(dateTime1(i));
    newDataMat(i,:) = [-9999, year, mon, day, hr, minute, sec, lat1(i), lon1(i), ...
        sog(i), cog(i), windSpeed(i), windDir(i), temp(i), sst(i), -9999, -9999, -9999, -9999];
end

%% COPS station log

[table, txt] = xlsread(inFile2,'cops'); %COPS metadata (Scott)
table(60:end,:) = [];

dateTime2 = table(:,2)+693960; % Begin COPS datetime
station = table(:,4);
lat2 = table(:,5);
lon2 = table(:,6);
% Use the true wind readings from the ship instead, not these.
windSpeed = table(:,9);% m/s
windDir = table(:,10); % degrees

cloud = table(:,8); % percent
% temp = table(:,7);
% relHum =  table(:,8);
% speed = table(:,16); % m/s
seas = table(:,11); % m

% % Format an array
% DataMat2 = nan*ones(length(dateTime),13);
% for i=1:length(dateTime)
%     [year, mon, day, hr, minute, sec] = datevec(dateTime2(i));
%     DataMat2(i,:) = [station(i) year, mon, day, hr, minute, sec, lat2(i), lon2(i), ...
%         windSpeed(i), windDir(i), cloud(i), seas(i)];
% end

%% Reconcile the two tables

%Now assign the stations from KORUS_seabass_synthesis
% 1. Find the nearest station timestamp within 30 min
% 2. Confirm the location is within 1.0 km
% 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)

for i=1:length(dateTime1)
    % dateTime3 can be hours apart
    [near_scalar, index] = find_nearest(dateTime1(i),dateTime2);
    % Within 30 min and stationary
    if abs(dateTime1(i) - dateTime2(index)) < datenum(0,0,0,0,30,0)
        kpdlon = kpdlat*cos(pi*lat1(i)/180);
        dlat = kpdlat*(lat1(i) - lat2(index)); 
        dlon = kpdlon*(lon1(i) - lon2(index)); 
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        
        if dist < 1.0
            if sog(i) < 0.77
                % sta year mon day hour min sec lat lon sog cog windSp 
                % windDir airTemp sst sss cloud seas dist
                newDataMat(i,1) = station(index);
                newDataMat(i,17) = cloud(index);
                newDataMat(i,18) = seas(index);
                newDataMat(i,19) = dist;
            else
                fprintf('Station: %d, Too fast\n', station(index))
                newDataMat(i,1) = -9999;
                newDataMat(i,17) = -9999;
                newDataMat(i,18) = -9999;
                newDataMat(i,19) = -9999;
            end
        else
            fprintf('Station: %d, Too far\n', station(index))
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
                    % sta year mon day hour min sec lat lon windSp windDir sst sss cloud seas
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%03.0f,%.1f,%.1f,%d,%0.1f\n',...
        newDataMat(i,[1:9, 12:13, 15:18]));
end

fclose(fidOut);




% %% Flow thru data
% [table, ~] = xlsread(inFile2);
% lat2 = table(:,7);
% lon2 = table(:,8);
% badIndex = 0*ones(1,length(lat2));
% for i=1:length(lat2)
%     if isnan(lat2(i)) || isnan(lon2(i)) || lat2(i)==-9999 || lon2(i)==-9999
%         badIndex(i) = 1;
%     end
% end
% table(logical(badIndex),:) = [];
% 
% year = table(:,1);
% month = table(:,2);
% day = table(:,3);
% hour = table(:,4);
% minute = table(:,5);
% second = table(:,6);
% dateTime2 = datenum(year,month, day, hour, minute, second);
% % dateTime = table(:,2)+693962;
% Wt = table(:,11);
% sal = table(:,13);
% speed = table(:,10);
% 
% % Format an array
% dataMat2 = nan*ones(length(year),4);
% for i=1:length(year)
% %     [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
%     dataMat2(i,:) = [ dateTime2(i),...
%         Wt(i), sal(i), speed(i)];
% end
% dataMat2(isnan(dataMat2)) = -9999;

% %% Station data
% [table, xHead] = xlsread(inFile3, 'cdom_flag');
% lat3 = table(:,7);
% lon3 = table(:,8);
% badIndex = 0*ones(1,length(lat3));
% for i=1:length(lat3)
%     if isnan(lat3(i)) || isnan(lon3(i)) || lat3(i)==-9999 || lon3(i)==-9999
%         badIndex(i) = 1;
%     end
% end
% table(logical(badIndex),:) = [];
% 
% yeardate = table(:,1);
% time = xHead(38:end,2);
% station = table(:,3);
% depth = table(:,4);
% alt = xHead(38:end,6);
% lat3 = table(:,7);
% lon3 = table(:,8);
% 
% 
% % Exclude stations at depth and JangMok stations
% % Timestamps are repeated in spreadsheet for stations at depth
% deep = find(depth >= 5);
% yeardate(deep) = [];
% station(deep) = [];
% time(deep) = [];
% alt(deep) = [];
% lat3(deep) = [];
% lon3(deep) = [];
% 
% jangMok = find(alt == "JangMok");
% yeardate(jangMok) = [];
% station(jangMok) = [];
% time(jangMok) = [];
% lat3(jangMok) = [];
% lon3(jangMok) = [];
% 
% % Don't need more than one station per station
% [C, ia, ic] = unique(station);
% yeardate = yeardate(ia);
% station = station(ia);
% time = time(ia);
% lat3 = lat3(ia);
% lon3 = lon3(ia);
% 
% % Format an array
% dataMat3 = nan*ones(length(yeardate),4);
% dateTime3 = nan*ones(length(yeardate),1);
% for i=1:length(yeardate)
% 	ydStr = num2str(yeardate(i));
%     year = str2double(ydStr(1:4));
%     month = str2double(ydStr(5:6));
%     day = str2double(ydStr(7:8));
%     timeStr = replace(time{i},"'",'');
%     hour = str2double(timeStr(1:2));
%     minute = str2double(timeStr(4:5));
%     second = str2double(timeStr(7:8));
%     dateTime3(i) = datenum(year, month, day, hour, minute, second);
%     dataMat3(i,:) = [ dateTime3(i), station(i), lat3(i), lon3(i) ];
% end
% dataMat3(isnan(dataMat3)) = -9999;


% %% Reconcile and combine the third table (station)
% % datestr(min(dateTime))
% % datestr(max(dateTime))
% % datestr(min(dateTime2))
% % datestr(max(dateTime2))
% % Use file 1 as basis
% 
% % sta year mon day hour min sec lat lon windSp windDir temp wT sal speed1 speed2 dist
% newDataMat = nan*ones(size(dataMat,1),17);
% 
% for i=1:length(dateTime)
%     [near_scalar, index] = find_nearest(dateTime(i),dateTime2);
%     [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
%     % dateTime collected every minute, dateTime2 every 20 sec
%     if abs(dateTime(i) - dateTime2(index)) < datenum(0,0,0,0,1,0) % within 1 minute        
%         newDataMat(i,:) = [nan, year, mon, day, hr, minute, sec, lat(i), lon(i), ...
%             dataMat(i,9), dataMat(i,10), dataMat(i,11), ...
%             dataMat2(index,2), dataMat2(index,3), dataMat(i,12), dataMat2(index,4), -9999];
%     else
% %         disp('Too much time gap')
%         newDataMat(i,:) = [nan, year, mon, day, hr, minute, sec, lat(i), lon(i), ...
%             dataMat(i,9), dataMat(i,10), dataMat(i,11), ...
%             -9999, -9999, dataMat(i,12), -9999, -9999];
%     end
% end
% speed1 = newDataMat(:,15);
% speed2 = newDataMat(:,16);
% speed1(speed1==-9999 | speed1 > 15) = nan;
% speed2(speed2==-9999 | speed2 > 15) = nan;
% plot(speed1,speed2,'.')
% xlabel('KORUS\_Onnuri\_Location\_AWS.xlsx; Speed of the vessel (m/s)')
% ylabel('KORUS\_flow\_thru.xlsx; speed\_f\_w [m/s]')
% print speeds -dpng
% % speed1 = newDataMat(:,15);
% % speed2 = newDataMat(:,16);
% 
% % Now assign the stations from KORUS_seabass_synthesis
% % 1. Find the nearest station timestamp within 30 min
% % 2. Confirm the location is within 1.0 km
% % 3. Confirm the ship is not moving more than 1.5 kts (0.77 m/s)
% for i=1:length(dateTime)
%     % dateTime3 can be hours apart
%     [near_scalar, index] = find_nearest(dateTime(i),dateTime3);
%     % Within 30 min and stationary
%     if abs(dateTime(i) - dateTime3(index)) < datenum(0,0,0,0,30,0)
%         lat1 = newDataMat(i,8);
%         lon1 = newDataMat(i,9);
%         kpdlon = kpdlat*cos(pi*lat1/180);
%         dlat = kpdlat*(lat1 - lat3(index)); 
%         dlon = kpdlon*(lon1 - lon3(index)); 
%         dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
%         
%         if dist < 1.0
%             if ((speed1(i) < 0.77) || isnan(speed1(i))) && ...
%                     ((speed2(i) < 0.77) || isnan(speed2(i))) && ...
%                     ~( isnan(speed1(i)) && isnan(speed2(i)) )
%                 newDataMat(i,1) = station(index);
%                 newDataMat(i,17) = dist;
%             else
%                 disp('Too fast')
%                 newDataMat(i,1) = -9999;
%             end
%         else
%             disp('Too far')
%             newDataMat(i,1) = -9999;
%         end
%     else
% %         disp('Too much time gap')
%         newDataMat(i,1) = -9999;
%     end
% end
%     
% 
% 




    
    
