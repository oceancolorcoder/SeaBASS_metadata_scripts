% Read in Excel data and output SeaBASS formatted data

datDir = './EXPORTS/Ancillary/';

inFile = [datDir 'exports_2018_FSG_Stationlog_clean.xlsx']; % wind, cloud, seas, has just a few readings per day
inFile2 = [datDir '/EXPORTS-EXPORTSNP_InLine-ALFA_process_20180811-20180912_R1.sb']; % wt, salhas data every 10 mins
outFile = [datDir 'EXPORTS_Ancillary.sb'];
inHeader = [datDir 'EXPORTS_Ancillary_header.sb'];

[table, xHead] = xlsread(inFile);
lat = table(:,9);
lon = table(:,12);
% badIndex = 0*ones(1,length(lat));
% for i=1:length(lat)
%     if isnan(lat(i)) || isnan(lon(i)) || lat(i)==-9999 || lon(i)==-9999
%         badIndex(i) = 1;
%     end
% end
% table(logical(badIndex),:) = [];

dateTime = datenum(2018,0,table(:,6));
windSpeed = table(:,14);
windDir = table(:,15);
cloud = table(:,13);
seas = table(:,16);

% % Format an array
% dataMat = nan*ones(length(dateTime),12);
% for i=1:length(dateTime)
%     [year, mon, day, hr, minute, sec] = datevec(dateTime(i));
%     dataMat(i,:) = [year, mon, day, hr, minute, sec, lat(i), lon(i), ...
%         windSpeed(i), windDir(i), cloud(i), seas(i)];
% end
% dataMat(isnan(dataMat)) = -9999;
    
% Pull in the second dataset
[data, header] = readsb(inFile2, 'MakeStructure', true);

% Walk through this more complete dataset, and tack on wind, cloud, seas
% fill with nans otherwise
% Use find_nearest, but not to exceed 10 minutes

dataMat = nan*ones(length(data.datenum),12+3);
tlim = minutes(10);
for i=1:length(data.datenum)
    [year, mon, day, hr, minute, sec] = datevec(data.datenum(i));
    dataMat(i,1:11) = [year, mon, day, hr, minute, sec, data.lat(i), ...
        data.lon(i), data.wt(i), data.sal(i), data.chl_stimf_ex405(i)];
    [near_time, index] = find_nearest(data.datenum(i),dateTime);
    if (data.datenum(i) > near_time-tlim) && (data.datenum(i) < near_time+tlim)
        dataMat(i,12) = windSpeed(index);
        dataMat(i,13) = windDir(index);
        dataMat(i,14) = cloud(index);
        dataMat(i,15) = seas(index);
    end
end
dataMat(isnan(dataMat)) = -9999;

% Transcribe the sb header and write file
fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');

line = '';
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);
% fprintf(fidOut,'%s\n','/end_header\n');

for i=1:size(dataMat,1)
%     fprintf(fidOut,'%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%3.0f,%.2f,%.2f\n',dataMat(i,:));
    fprintf(fidOut,'%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%.2f,%.1f,%.2f,%03.0f,%.0f,%.2f\n',dataMat(i,:));
end

fclose(fidOut);
    
    
