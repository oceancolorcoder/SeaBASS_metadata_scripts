% USGS mock-up for lat long

wipe

lat = 37.800;
lon = -122.300;
station = 1;
sst = 18;
wind = 4;
wDir = 45;
waves = 0.5;
cloud = 30;
sal = 33;

startCruise = datetime(datenum(2022,8,16,14,0,0),"ConvertFrom","datenum","TimeZone","UTC");
endCruise = datetime(datenum(2022,8,16,22,00,00),"ConvertFrom","datenum","TimeZone","UTC");

dateTime1 = startCruise:minutes(1):endCruise;

datDir = '~/Projects/HyperPACE/field_data/metadata/USGS/';
inHeader = fullfile(datDir,'USGS_Ancillary_header.sb');

outFile = fullfile(datDir,'USGS_mock_Ancillary.sb');

for i=1:length(dateTime1)
    dataMat(i,:) = [station, dateTime1(i).Year, dateTime1(i).Month, dateTime1(i).Day, ....
        dateTime1(i).Hour, dateTime1(i).Minute, dateTime1(i).Second, ...
        lat, lon, ...
        sst, wind, wDir, waves,cloud,sal];
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
    %               station,year,month,day,hour,minute,second,lat,lon,Wt,wind,wdir,waveht,cloud,sal
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.3f,%.3f,%.1f,%.1f,%d,%.1f,%d,%.3f\n',dataMat(i,:));
end

fclose(fidOut);

%% Don't forget to fcheck the file.
