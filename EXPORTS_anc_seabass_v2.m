% Read in Excel data and output SeaBASS formatted data

datDir = './';
inFile1 = [datDir 'exports_2018_FSG_Stationlog_clean.xlsx']; % wind, cloud, seas, has just a few readings per day
% inFile2 = [datDir 'EXPORTS-EXPORTSNP_InLine-ALFA_process_20180811-20180912_R1.sb']; % wt, salhas data every 10 mins
inFile3 = [datDir 'SR1812_uwmet_v1.csv']; % Comprehensive ship readings including heading, sst, sss, wind, etc. every few seconds
outFile = [datDir 'EXPORTS_Ancillary.sb'];
inHeader = [datDir 'EXPORTS_Ancillary_header.sb'];

% Import first ancillary data file
fprintf('Read %s\n',inFile1)
[data1, header1] = xlsread(inFile1,'IOP cage');
lat = data1(:,9);
lon = data1(:,12);

dateTime1 = datenum2datetime(datenum(2018,0,data1(:,6)));
windSpeed1 = data1(:,14);
windDir1 = data1(:,15);
cloud1 = data1(:,13);
seas1 = data1(:,16);

% Import SAS sheet
fprintf('Read %s\n',inFile1)
[data2, header2] = xlsread(inFile1,'SAS');
sTime = datetime(data2(:,2),'convertfrom','excel'); % incomplete format
sDateTime = NaT(1,length(sTime));
for i=1:length(sTime)
    yeardate = num2str(data2(i,1)); % grab date from first column
    year = str2double(yeardate(1:4));
    mon = str2double(yeardate(5:6));
    day = str2double(yeardate(7:8));
    [hh,mm,ss] = hms(sTime(i));    
    sDateTime(i) = datetime(year, mon, day, hh, mm, ss);    
end
eDateTime = datetime(data2(:,3),'convertfrom','excel');
offset = data2(:,6);
    
% % Import second data file
% % fprintf('Read %s\n',inFile2)
% [data2, header2] = readsb(inFile2, 'MakeStructure', true);

% Import third and most complete data file
fprintf('Read %s\n',inFile3)
data3 = readmatrix(inFile3, 'NumHeaderLines', 4, 'TreatAsMissing', '-99');

% Walk through this more complete dataset, and tack on wind, cloud, seas
% fill with nans otherwise
% Use find_nearest, but not to exceed 10 minutes
dataMat = NaN(length(data3),12+3+1);

tlim = minutes(10);
disp('Looping')
for i=1:length(data3)
    % /fields=year,month,day,hour,minute,second,lat,lon,heading,Wt,sal,wind,wdir,cloud,waveht
    dateTime3 = datetime(data3(i,1), data3(i,2), data3(i,3), data3(i,4), data3(i,5), data3(i,6));
    dataMat(i,1:13) = [data3(i,1), data3(i,2), data3(i,3), data3(i,4), data3(i,5), data3(i,6), data3(i,8), ...
        data3(i,9), data3(i,12), data3(i,13), data3(i,14), data3(i,29), data3(i,30)];
    
    [near_time, index] = find_nearest(dateTime3,dateTime1);
    if (dateTime3 > near_time-tlim) && (dateTime3 < near_time+tlim)
%         dataMat(i,12) = windSpeed1(index);
%         dataMat(i,13) = windDir1(index);
        dataMat(i,14) = cloud1(index);
        dataMat(i,15) = seas1(index);
    end
    
    % For each timestamp in datMat, loop over each set of start/end times
    % in SAS, and if it matches, populate with offset
    % This is very, very slow...
    for n=1:length(sDateTime)
        if dateTime3 >= sDateTime(n) && dateTime3 <= eDateTime(n)
            dataMat(i,16) = offset(n);
        end
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
    fprintf(fidOut,'%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.2f,%.2f,%.1f,%.2f,%03.0f,%.0f,%.2f,%.1f\n',dataMat(i,:));
end

fclose(fidOut);
    
    
