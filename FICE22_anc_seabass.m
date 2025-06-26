% FRM4SOC2 FICE22 campaign, July 2022

wipe

lat = 45.314;
lon = 12.508;
% station = 'AAOT';

startCruise = datetime(datenum(2022,7,11,0,0,0),"ConvertFrom","datenum","TimeZone","UTC");
endCruise = datetime(datenum(2022,7,21,10,35,00),"ConvertFrom","datenum","TimeZone","UTC");

datDir = '~/Projects/HyperPACE/field_data/metadata/FICE22';

% date/time(UTC+1) tideht wdir10m wspeed10m wmax10m  wave wavemax pressure temp watertemp humidity solarrad(PAR?) rain
inFile1 = fullfile(datDir,'Stazione_Piattaforma_20220721.xlsx'); % https://www.comune.venezia.it/content/3-piattaforma-ISMAR-CNR = AAOT

%date time(UTC) cloud(%) relAz comments
inFile2 = fullfile(datDir,'FICE22_NASA_field_log_pySAS.xlsx'); 

%date; time; cond; press; sal; dens; -; -; odo; ooxsat; -----
inFile3 = fullfile(datDir,'ptf-3m_07_2022.txt');

% AOC.Venice.Aerosol_Optical_Depth
inFile4 = '~/GitRepos/AERONET/dat/Aeronet_OC_FICE22_20220711_20220722_Venise_L15.mat';

inHeader = fullfile(datDir,'FICE22_Ancillary_header.sb');

outFile = fullfile(datDir,'FICE22_Ancillary.sb');

%% inFile1: Met data every 5 minutes
fprintf('Read File 1; Met data: %s\n',inFile1)
% time lat lon cloud seas
[data1, header1] = xlsread(inFile1,'Sheet1');

dateTime1 = datetime(data1(:,1),'ConvertFrom','excel','TimeZone','UTC+1');
dateTime1.TimeZone = 'UTC';
notCruise = dateTime1  < startCruise | dateTime1 > endCruise;
dateTime1(notCruise) = [];
data1(notCruise,:) = [];

lat1 = repmat(lat,size(data1,1),1);
lon1 = repmat(lon,size(data1,1),1);
windDir1 = data1(:,3); % degrees
windSpeed1 = data1(:,4); % m/s at 10m
seas1 = data1(:,6); % m
airT = data1(:,9); % Air temp at 18m
sst1 = data1(:,10); % SST
% rh1 = data1(:,11); % %

%% inFile2: Field log

fprintf('Read File 2; Field log: %s\n',inFile2)
[data2, header2] = xlsread(inFile2);
data2(data2==-999) = nan;

dateTime2 = datetime(data2(:,2),'ConvertFrom','excel','TimeZone','UTC') + data2(:,3);
% This often drops the seconds down from 00 to 59 of the previous minute
dateTime2 = dateshift(dateTime2,'start','minute','nearest');
notCruise = dateTime2  < startCruise | dateTime2 > endCruise;
dateTime2(notCruise) = [];
data2(notCruise,:) = [];

station = data2(:,1);
cloud2 = data2(:,4);
relAz2 = data2(:,5); % pySAS setting/target

%% Walk through first dataset (5min), and tack on station and cloud
% 1. Find the nearest field log timestamp within 15 min

% fill with nans otherwise
% Use find_nearest, but not to exceed 10 minutes
dataMat = NaN(length(data1),16);

tLim = minutes(5); % Station data are logged for 5 minutes by non-automated radiometers

disp('Looping')
for i=1:length(data1)    
    
    % /fields=station,year,month,day,hour,minute,second,lat,lon,At,Wt,wind,wdir,waveht,cloud,sal,aot    
    dataMat(i,2:14) = [dateTime1(i).Year, dateTime1(i).Month, dateTime1(i).Day, ....
        dateTime1(i).Hour, dateTime1(i).Minute, dateTime1(i).Second, ...
        lat1(i), lon1(i), ...
        airT(i), sst1(i), windSpeed1(i), windDir1(i), seas1(i)];
    
    % FOR FICE22, Only accept the station time from log and up to 5 minutes
    % after
    whr = dateTime1(i) >= dateTime2 & dateTime1(i) < dateTime2+tLim;
    if sum(whr) == 1        
        dataMat(i,1) = station(whr);
        dataMat(i,15) = cloud2(whr);
    elseif sum(whr) > 1
        disp('Multiple matches error.')
    end
       

%     [near_time, index] = find_nearest(dateTime1(i),dateTime2);
%     if (dateTime1(i) > near_time-tLim) && (dateTime1(i) < near_time+tLim)
%         dataMat(i,1) = station(index);
%         dataMat(i,14) = cloud2(index);
% %         dataMat(i,15) = relAz2(index);
%     end
    
end
dataMat(isnan(dataMat)) = -9999;

%% inFile3: Hydrology every 10 minutes at -3m depth

fprintf('Read File 3; Hydrographic -3m data: %s\n',inFile3)
fid = fopen(inFile3);
%date; time; cond; press; sal; dens; -; -; odo; ooxsat; -----
formatSpec = '%02f/%02f/%02f %02f.%02f.%02f.%03f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f';
C = textscan(fid,formatSpec,...
    'Delimiter',';','HeaderLines',9);
fclose(fid);

dateTime3 = datetime(datenum(C{1,3}+2000,C{1,2},C{1,1},C{1,4},C{1,5},C{1,6}),...
    'ConvertFrom','datenum','TimeZone','UTC'); % UTC confirmed by Gavin
sal = C{1,11};

disp('Looping')
for i=1:length(data1)               
    [~,index] = find_nearest(dateTime1(i),dateTime3);
    if abs(dateTime1(i) - dateTime3(index)) < tLim
        dataMat(i,16) = sal(index);
    end
end

%% Aerosol Optical Depth from AERONET (-OC, as it happens)
load(inFile4) % AOC structure

for i=1:length(dateTime1)
    [dtMatch,index] = find_nearest(dateTime1(i),AOC.Venise.Datetime);

    fprintf('Nearest AOT match within %s\n',abs(dateTime1(i)-dtMatch))

    % THIS MAY BE IMPROVED USING AERONET AOD FILES INSTEAD OF AERONET-OC
    % FILES 
    dataMat(i,17) = AOC.Venise.Aerosol_Optical_Depth(index,5); % This may be many hours off, and is at 551.9 nm, not 550 nm
end

%% Transcribe the sb header and write file
fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');
line = '';

fprintf('Outputing seabass file: %s\n',outFile)
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end
fclose(fidIn);

for i=1:size(dataMat,1)
    %               station,year,month,day,hour,minute,second,lat,lon,At,Wt,wind,wdir,waveht,cloud,sal,aot_550
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.3f,%.3f,%.1f,%.1f,%.1f,%d,%.1f,%d,%.3f,%.4f\n',dataMat(i,:));
end

fclose(fidOut);

%% Don't forget to fcheck the file.
