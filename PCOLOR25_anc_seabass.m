wipe
[fontName,~] = machine_prefs;

% Costa Rica sport fisher
% minimal logs only

%% Setup
datDir = '~/Projects/HyperPACE/field_data/metadata/PCOLOR25/';

% PCOLOR25

% Updated field notes. Origin unknown
inFile = [datDir 'PCOLOR25_metadata_updated.xlsx'];
outFile = [datDir 'PCOLOR25_Ancillary.sb'];
inHeader = [datDir 'PCOLOR25_Ancillary_header.sb'];

%% End setup

%% Field log
table = readtable(inFile);
station = table{:,1};
dateTime = datetime(table{:,4},'TimeZone','UTC') + days(table{:,5});
lat = table{:,6};
lon = table{:,7};
sst = table{:,11};
sss = table{:,12};
cloud = table{:,21};

newDataMat = nan(length(dateTime),12);

newDataMat(:,1) = station;
newDataMat(:,2) = year(dateTime(:));
newDataMat(:,3) = month(dateTime(:));
newDataMat(:,4) = day(dateTime(:));
newDataMat(:,5) = hour(dateTime(:));
newDataMat(:,6) = minute(dateTime(:));
newDataMat(:,7) = second(dateTime(:));
newDataMat(:,8) = lat(:);
newDataMat(:,9) = lon(:);
newDataMat(:,10) = cloud(:);
newDataMat(:,11) = sst(:);
newDataMat(:,12) = sss(:);
% sta year mon day hour min sec lat lon(9) cloud sst sss(12)


%%
fh = figure('Position',[1904         306        1116         701]);
subplot(5,1,1)
plot(dateTime,newDataMat(:,9),'.')
ylabel('lon')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

% subplot(5,1,2)
% plot(dateTime,newDataMat(:,10),'.')
% ylabel('wind')
% xlim([dateTime(1) dateTime(end)])
% set(gca,'FontName',fontName,'FontSize',14)
% grid on

subplot(5,1,3)
plot(dateTime,newDataMat(:,11),'.')
ylabel('sst')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

subplot(5,1,4)
plot(dateTime,newDataMat(:,10),'.')
ylabel('cloud')
xlim([dateTime(1) dateTime(end)])
set(gca,'FontName',fontName,'FontSize',14)
grid on

% subplot(5,1,5)
% plot(dateTime,newDataMat(:,14),'.')
% ylabel('seas')
% xlim([dateTime(1) dateTime(end)])
% set(gca,'FontName',fontName,'FontSize',14)
% grid on

exportgraphics(fh,'plt/PCOLOR25_timeline.png')

%%
newDataMat(isnan(newDataMat)) = -9999;
% fix 60 second glitch
ind = newDataMat(:,7)>59.9;
newDataMat(ind,7) = 0;
newDataMat(ind,6) = newDataMat(ind,6)+1;
ind = newDataMat(:,7)<1;
newDataMat(ind,7) = 0;
%% Output

fidIn = fopen(inHeader,'r');
fidOut = fopen(outFile,'w');

line = '';
while ~contains(line,'end_header')
    line = fgetl(fidIn);
    fprintf(fidOut,'%s\n',line);
end

fclose(fidIn);
for i=1:size(newDataMat,1)
                  % sta year mon day hour min sec lat lon(9) cloud sst sss(12)  
    fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.1f,%.1f\n',...
        newDataMat(i,:));
end
fclose(fidOut);