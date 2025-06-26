% FRM4SOC2 FICE22 campaign, July 2022

% Work from my FICE22_anc_seabass.m output and the ancillary file provided
% by Giorgio

wipe

% Limit this to just the sample station day
startCruise = datetime(datenum(2022,7,19,8,0,0),"ConvertFrom","datenum","TimeZone","UTC");
endCruise = datetime(datenum(2022,7,19,9,0,0),"ConvertFrom","datenum","TimeZone","UTC");

datDir = '~/Projects/HyperPACE/field_data/metadata/FICE22';

inFile1 = fullfile(datDir,'FICE22_Ancillary.sb');

inFile2 = fullfile(datDir,'FICE22_TriOS_Ancillary_TrueRelAz_V2.sb'); 

inHeader = fullfile(datDir,'FICE22_TriOS_Ancillary_TrueRelAz_V3_header.sb');

outFile = fullfile(datDir,'FICE22_Ancillary_TriOS.sb');

%% inFile1: pySAS Metadata
fprintf('Read File 1; pySAS metadata: %s\n',inFile1)

[data1, sbHeader1] = readsb(inFile1,'MakeStructure', true);
dateTime1 = datetime(data1.datenum,'ConvertFrom','datenum',...
    'TimeZone','UTC');
notCruise = dateTime1  < startCruise | dateTime1 > endCruise;
dateTime1(notCruise) = [];
data1 = structfun(@(x) x(~notCruise),data1,'Un',0);

%% inFile2: Giorgio's ancillary file

fprintf('Read File 2; TriOS metadata: %s\n',inFile2)
[data2, sbHeader2] = readsb(inFile2,'MakeStructure', true);
dateTime2 = datetime(data2.datenum,'ConvertFrom','datenum',...
    'TimeZone','UTC');


%% Walk through first dataset (5min), and tack on station and cloud
% 1. Find the nearest TriOS timestamp within 15 min

% fill with nans otherwise
% Use find_nearest, but not to exceed 10 minutes
dataMat = NaN(length(dateTime1),18);

tLim = minutes(5); % Station data are logged for 5 minutes by non-automated radiometers

for i=1:length(dateTime1)    
    
    % /fields=station,year,month,day,hour,minute,second,lat,lon,At,Wt,wind,wdir,waveht,cloud,sal,aot,relaz    
    dataMat(i,1:17) = [str2num(data1.station{i}) data1.year(i) data1.month(i) data1.day(i) data1.hour(i) ...
        data1.minute(i) data1.second(i) data1.lat(i) data1.lon(i) data1.at(i) data1.wt(i) ...
        data1.wind(i) data1.wdir(i) data1.waveht(i) data1.cloud(i) data1.sal(i) data1.aot(i) ];
        
    whr = abs(dateTime1(i) - dateTime2) <= tLim;
    if sum(whr) == 1        
        dataMat(i,18) = data2.relaz(whr);
    elseif sum(whr) > 1
        disp('Multiple matches error.')
    else
        dataMat(i,18) = nan;
    end
    
end
dataMat(isnan(dataMat)) = -9999;

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
    %               station,year,month,day,hour,minute,second,lat,lon,At,Wt,wind,wdir,waveht,cloud,sal,aot_550,relaz
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.3f,%.3f,%.1f,%.1f,%.1f,%d,%.1f,%d,%.3f,%.4f,%.1f\n',dataMat(i,:));
end

fclose(fidOut);

%% Don't forget to fcheck the file.
