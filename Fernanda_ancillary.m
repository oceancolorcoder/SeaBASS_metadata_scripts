wipe

inHeader = '~/Projects/HyperCP/Training/FICE2024/Fernanda Giannini/Fernanda_sb_header.txt';
fp = '~/Projects/HyperCP/Training/FICE2024/Fernanda Giannini/ancillary_renomo1_FG_v4.sb';
outFile = '~/Projects/HyperCP/Training/FICE2024/Fernanda Giannini/ancillary_renomo1_FG_v5.sb';

[data, header] = readsb(fp, 'MakeStructure', true);

station = [data.station];
dateTime = datetime(datenum(...
    [data.year],[data.month],[data.day],[data.hour],[data.minute],[data.second]),...
    'ConvertFrom','datenum','TimeZone','UTC');

dataMat = [[data.lat],[data.lon],[data.wind],[data.wdir],[data.at],[data.wt],...
    [data.sal],[data.relaz]];

dataMat (:,8) = 120;

newDateTime = (datetime(2023,10,18,12,15,00,'TimeZone','UTC'):...
    minutes(2):datetime(2023,10,20,15,15,00,'TimeZone','UTC'))';

newDataMat = interp1(dateTime,dataMat,newDateTime,'nearest','extrap');

newDataMat = [year(newDateTime) month(newDateTime) day(newDateTime) hour(newDateTime)...
    minute(newDateTime) second(newDateTime) newDataMat];

for i=1:length(newDateTime)
    [testTime,iTest] = find_nearest(newDateTime(i),dateTime);
    if (newDateTime(i) - testTime) < minute(1)
        if strcmp(station(iTest),'NaN')
            newStation(i) = -9999;
        else
            newStation(i) = str2double(station{2});
        end
    else
        newStation(i) = -9999;
    end
end
newStation = newStation';
newDataMat = [newStation newDataMat];


%%
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
    %               station,year,month,day,hour,minute,second,lat,lon,wind,wdir,At,Wt,sal,relaz
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.3f,%.3f,%.1f,%d,%.1f,%.1f,%.1f,%d\n',newDataMat(i,:));
end

fclose(fidOut);