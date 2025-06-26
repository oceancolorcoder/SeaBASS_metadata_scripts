% Read in field logs and ship data and output SeaBASS formatted data
wipe

datDir = '~/Projects/HyperPACE/field_data/metadata/EXPORTSNA/';

% Field notes are still incomplete and Scott is on vacation. Start with the
% ship data

% The following file series were downloaded episodically by Scott on the ship:
% 1. surfm: air temp, relative humidity (no need to include these)
% 2. sbe45: SST*, SSS*
% 3. eadp: bottom depth
% 4. mvpos: GPS*, SOG*, COG (SOG is not a valid SeaBASS field)
% 5. sgyr: Gyro (redundant with mvatt)
% 6. mvatt: pitch*, roll*, heading*
% 7. truwind: wind speed*, direction*
% 8. wamos: significant wave height*, direction* (magnitude is lower than experienced)

% Field notes:
logFile = fullfile(datDir,'EXPORTSNA_2021_FSG_Stationlog_updated.xlsx');

% Subset final database to courser timestampe
subTime = 30; % seconds


fSep = filesep;
outFile = [datDir 'EXPORTSNA_Ancillary.sb'];
inHeader = [datDir 'EXPORTSNA_Ancillary_header.sb'];

kpdlat = 111.325; %km per deg. latitude

%% Pitch & Roll (1 Hz)
%   datenum, heading, pitch, roll
name = 'mvatt';
fp  = fullfile(datDir,'ship',name);
fprintf('Read mvatt; pitch and roll: %s\n',fp)
varNames = {'label','date','time','instr','gpstime','heading','roll','pitch','heave','roll_sd','pitch_sd','heading_sd','flag','flag'} ;
varTypes = {'char','datetime','datetime','char','double','double','double','double','double','double','double','double','int8','int8'} ;
delimiter = ',';
dataStartLine = 1;
extraColRule = 'ignore';
opts = delimitedTextImportOptions('VariableNames',varNames,...
    'VariableTypes',varTypes,'Delimiter',delimiter,'DataLines', dataStartLine,...
    'ExtraColumnsRule',extraColRule);
opts = setvaropts(opts,'date','InputFormat','dd/MM/yy');
opts = setvaropts(opts,'time','InputFormat','HH:mm:ss.SSS');

fList = dir([fp fSep '*.' name]);
if ~isempty(fList)
PRmat = nan(0,4);
for i=1:numel(fList)
    T = readtable([fList(i).folder fSep fList(i).name],opts);
    fprintf('Reading in %s\n', fList(i).name)
    start = size(PRmat,1) +1;
    stop = start + size(T,1) -1;
    PRmat(start:stop,1) = datenum(T{:,'time'}-dateshift(T{:,'time'},'start','day') + T{:,'date'});
    PRmat(start:stop,2:4) = T{:,{'heading','pitch','roll'}};
end
PRmat = sortrows(PRmat,1);
else
    fprintf('No %s file found\n',fp)
    return
end
% Pitch/Roll are about 1Hz
% Ship gets underway at exactly 07:34:47.665 on 5/1/2021, still going 8.3
% knots at the end of the last GPS file.
% Interpolate to 1Hz (integer seconds) during the times when SATTHS was
% offline, and every minute after that
start = datetime(2021,5,1,7,34,47);
dT1 = datetime(PRmat(:,1),'Convertfrom','Datenum');
dTb4 = dT1(dT1 > start & dT1 < datetime(2021,5,12,0,0,0));
dTb4Interp = (dTb4(1):seconds(1):dTb4(end))';
dTafter = dT1(dT1 >= datetime(2021,5,12,0,0,0));
dTafterInterp = (dTafter(1):minutes(1):dTafter(end))';
dateTimeInterp = vertcat(dTb4Interp,dTafterInterp);

PRmatInterp = interp1(dT1,PRmat,dateTimeInterp);
clear dT*

figure
plot(PRmat(:,1),PRmat(:,3))
datetick('x','mm/dd HH','keepticks')
hold on
plot(PRmatInterp(:,1),PRmatInterp(:,3),'r')
ylabel('Pitch')
title(name)
print(sprintf('plt/%s.png',name),'-dpng')
clear PRmat T

%% GPS
%   datenum, lat, lon, cog, sog
name = 'mvpos';
fp  = fullfile(datDir,'ship',name);
fprintf('Read %s; GPS position: %s\n',name,fp)
varNames = {'label','date','time','instr','null1','nsbseen','sbused',...
    'hdop','vdop','pdop','gpstime',...
    'lat_NS','lat_deg','lat_min','lon_EW','lon_deg','lon_min',...
    'alt','prec','mode','cog','sog','null2','null3','heading'} ;
varTypes = {'char','datetime','datetime','char','double','int8','double',...
    'double','double','double','double',...
    'char','int8','double','char','int8','double',...
    'double','int8','int8','double','double','double','double','double'};
opts = delimitedTextImportOptions('VariableNames',varNames,...
    'VariableTypes',varTypes,'Delimiter',delimiter,'DataLines', dataStartLine,...
    'ExtraColumnsRule',extraColRule);
opts = setvaropts(opts,'date','InputFormat','dd/MM/yy');
opts = setvaropts(opts,'time','InputFormat','HH:mm:ss.SSS');

fList = dir([fp fSep '*.' name]);
GPSmat = nan(0,5);
for i=1:numel(fList)
    T = readtable([fList(i).folder fSep fList(i).name],opts);
    fprintf('Reading in %s\n', fList(i).name)
    start = size(GPSmat,1) +1;
    stop = start + size(T,1) -1;
    GPSmat(start:stop,1) = datenum(T{:,'time'}-dateshift(T{:,'time'},'start','day') + T{:,'date'});
    NS = T{:,'lat_NS'};
    NSlogic = ones(numel(NS),1);
    NSlogic(strcmpi(NS,'S')) = -1;
    GPSmat(start:stop,2) = NSlogic.*(double(T{:,'lat_deg'}) + T{:,'lat_min'}/60);
    EW = T{:,'lon_EW'};
    EWlogic = ones(numel(EW),1);
    EWlogic(strcmpi(EW,'W')) = -1;
    GPSmat(start:stop,3) = EWlogic.*(double(T{:,'lon_deg'}) + T{:,'lon_min'}/60);
    GPSmat(start:stop,4:5) = T{:,{'cog','sog'}};
end
GPSmat = sortrows(GPSmat,1);

% GPS are about 1Hz
% Interpolate to P&R
dT1 = datetime(GPSmat(:,1),'Convertfrom','Datenum');
GPSmatInterp = interp1(dT1,GPSmat,dateTimeInterp);
clear dT*

figure
plot(GPSmat(:,1),GPSmat(:,5))
ylabel('SOG')
datetick('x','mm/dd HH','keepticks')
hold on
plot(GPSmatInterp(:,1),GPSmatInterp(:,5),'r')
title(name)
print(sprintf('plt/%s_SOG.png',name),'-dpng')

%% CTD (pumped from 5.5m below surface; use SBE38 for temp data near the intake)
%   datenum, sst, sss
name = 'sbe45';
fp  = fullfile(datDir,'ship',name);
fprintf('Read %s; CTD: %s\n',name,fp)
varNames = {'label','date','time','instr','null1','temp_h','cond',...
    'salin','sndspeed','temp_r'} ;
varTypes = {'char','datetime','datetime','char','int8','double','double',...
    'double','double','double'};
opts = delimitedTextImportOptions('VariableNames',varNames,...
    'VariableTypes',varTypes,'Delimiter',delimiter,'DataLines', dataStartLine,...
    'ExtraColumnsRule',extraColRule);
opts = setvaropts(opts,'date','InputFormat','dd/MM/yy');
opts = setvaropts(opts,'time','InputFormat','HH:mm:ss.SSS');

fList = dir([fp fSep '*.' name]);
CTDmat = nan(0,3);
for i=1:numel(fList)
    T = readtable([fList(i).folder fSep fList(i).name],opts);
    fprintf('Reading in %s\n', fList(i).name)
    start = size(CTDmat,1) +1;
    stop = start + size(T,1) -1;
    CTDmat(start:stop,1) = datenum(T{:,'time'}-dateshift(T{:,'time'},'start','day') + T{:,'date'});
    CTDmat(start:stop,2:3) = T{:,{'temp_r','salin'}};
end
CTDmat = sortrows(CTDmat,1);

% QC salinity(34 psu based on visual screening)
CTDmat(CTDmat(:,3) < 34, 3) = nan;
filter = ~isnan(CTDmat(:,3));

% CTD are about 1Hz
% Interpolate to Pitch&Roll
%       Some NaNs due to lack of extrapolation
dT1 = datetime(CTDmat(:,1),'Convertfrom','Datenum');
CTDmatInterp = interp1(dT1(filter),CTDmat(filter,:),dateTimeInterp);
clear dT*

figure
plot(CTDmat(:,1),CTDmat(:,2))
ylabel('SST')
datetick('x','mm/dd HH','keepticks')
hold on
plot(CTDmatInterp(:,1),CTDmatInterp(:,2),'r')
title(name)
print(sprintf('plt/%s_SST.png',name),'-dpng')

figure
plot(CTDmat(:,1),CTDmat(:,3))
ylabel('SSS')
datetick('x','mm/dd HH','keepticks')
hold on
plot(CTDmatInterp(:,1),CTDmatInterp(:,3),'r')
title(name)
print(sprintf('plt/%s_SSS.png',name),'-dpng')

%% Wind
% No info on sensor location, etc. Speed and direction are "abs", so presumably
% corrected/True? No units provided (Looks like km/h). Apparently 10s intervals
%
%   datenum, windspeed,winddir

name = 'truwind';
fp  = fullfile(datDir,'ship',name);
fprintf('Read %s; Wind: %s\n',name,fp)
varNames = {'yy','doy','time','abswspd','unknown1','abswdir','unknown2'} ;
varTypes = {'double','double','datetime','double','int8','double','int8'};
varWidths = [3, 4, 11,13, 4, 13,3];
dataStartLine = 3;
opts = fixedWidthImportOptions('VariableNames',varNames,...
    'VariableTypes',varTypes,'VariableWidths',varWidths,'DataLines', dataStartLine);
opts = setvaropts(opts,'time','InputFormat','HH:mm:ss');

fList = dir([fp fSep '*.txt']);
Windmat = nan(0,3);
for i=1:numel(fList)
    T = readtable([fList(i).folder fSep fList(i).name],opts);
    fprintf('Reading in %s\n', fList(i).name)
    start = size(Windmat,1) +1;
    stop = start + size(T,1) -1;
    % no vectorwise option in yearday
    for n=0:size(T,1)-1
        Windmat(start+n:stop+n,1) = datenum(T{n+1,'time'}-dateshift(T{n+1,'time'},'start','day')) + yearday([2000+T{n+1,'yy'},T{n+1,'doy'}]);
    end
    Windmat(start:stop,2:3) = T{:,{'abswspd','abswdir'}};
end
Windmat = sortrows(Windmat,1);
[dT1u,ia,ic] = unique(Windmat(:,1));
Windmat1 = Windmat(ia,:);

% Wind data @ 10s with a number of non-unique timestamps
% Interpolate to 1 Hz P&R
dT1 = datetime(Windmat1(:,1),'Convertfrom','Datenum');

% NOTE: Interpolation of wind direction will introduce errors %%%%%%
WindmatInterp = interp1(dT1,Windmat1,dateTimeInterp);
clear dT*

figure
plot(Windmat(:,1),Windmat(:,2))
ylabel('Windspeed')
datetick('x','mm/dd HH','keepticks')
hold on
plot(WindmatInterp(:,1),WindmatInterp(:,2),'r')
title(name)
print(sprintf('plt/%s_Windspeed.png',name),'-dpng')

%% Station Log file (Waiting for Scott...)
%   station, sky, seas
%   Unlike the ship files, these are only matched for stations

tLim = minutes(60); %
dLim = 1; % km
% sLim = 0.77; % m/s (1.5 kts)

varNames = {'Station','R2R','date','beg time','duration','end time','yearday',...
    'yearday decimal','deg','min','Latitude','deg','min','Longitude',...
    'Sky Conditions','wind speed kn','direction','seas','water depth',...
    'filtered','Notes'};
varTypes = {'int8','char','datetime','datetime','duration','datetime','int16',...
    'double','double','double','double','double','double','double',...
    'int8','double','int16','double','int16','char','char'};
opts = spreadsheetImportOptions('VariableNames',varNames,...
    'VariableTypes',varTypes,...
    'PreserveVariableNames',true,...
    'DataRange','B11:V48','Sheet','IOP cage');

fprintf('Read Log File: %s\n',logFile)
Tdata = readtable(logFile,opts);
lat1 = Tdata{:,'Latitude'};
lon1 = Tdata{:,'Longitude'};
dateNum1 = datenum(Tdata{:,'beg time'}-dateshift(Tdata{:,'beg time'},'start','day') + Tdata{:,'date'});

% Create a new ancillary matrix and populate from PRmatInterp,
% GPSmatInterp, CTDmatInterp, and then match in time/location within
% thresholds to Tdata, the IOP log with station, cloud, and seas
newMat = nan*GPSmatInterp;
f = waitbar(0,'Matching stations from log...');
for i=1:size(GPSmatInterp,1)
    [year,mon,day,hr,min,sec]=datevec(PRmatInterp(i,1));
    newMat(i,1) = nan;                                          % station
    newMat(i,2) = year; newMat(i,3) = mon; newMat(i,4) = day;   % date
    newMat(i,5) = hr; newMat(i,6) = min; newMat(i,7) = round(sec);     % time
    newMat(i,8) = GPSmatInterp(i,2);                            % lat
    newMat(i,9) = GPSmatInterp(i,3);                            % lon
    newMat(i,10) = round(PRmatInterp(i,2));                            % heading
    newMat(i,11) = CTDmatInterp(i,2);                              % Wt
    newMat(i,12) = CTDmatInterp(i,3);                              % sal
    newMat(i,13) = 0.2778 * WindmatInterp(i,2);                          % wind in m/s
    newMat(i,14) = round(WindmatInterp(i,3)); % This has interp errors % wdir
    newMat(i,15) = nan;                                         % cloud
    newMat(i,16) = nan;                                         % waveht
    newMat(i,17) = PRmatInterp(i,3);                            % pitch
    newMat(i,18) = PRmatInterp(i,4);                            % roll
        
    [near_time, index] = find_nearest(GPSmatInterp(i,1),dateNum1);
    if (GPSmatInterp(i,1) >= near_time-tLim) && (GPSmatInterp(i,1) < near_time+tLim)
        kpdlon = kpdlat*cos(pi*lat1(index)/180);
        dlat = kpdlat*(GPSmatInterp(i,2) - lat1(index));
        dlon = kpdlon*(GPSmatInterp(i,3) - lon1(index));
        dist = sqrt(dlat.^2 + dlon.^2); % distance to station [km]
        if dist < dLim
            newMat(i,1) =  Tdata{index,'Station'};
            newMat(i,15) =  Tdata{index,'Sky Conditions'}; % percent
            newMat(i,16) =  Tdata{index,'seas'};    % m
        end
    end
    
    % Update waitbar and message
    if rem(i,1000) ==0
        waitbar(i/size(GPSmatInterp,1),f)
    end
end
close(f)

newMat(isnan(newMat)) = -9999.0;

%% Subset to courser timestamp from 1 HZ
dateTime = datetime(newMat(:,2),newMat(:,3),newMat(:,4),newMat(:,5),newMat(:,6),newMat(:,7));
dateTimeNew = dateTime(1):seconds(subTime):dateTime(end);
% Use NEAREST to avoid interpolating the -9999s
% station = newMat(:,1);
% station1 = interp1(dateTime, station, dateTimeNew,'nearest');
newMat2 = interp1(dateTime,newMat,dateTimeNew,'nearest');
% newMat2(:,1) = station1;
% Override interpolated datetimes to restore whole numbers
% for i=size(newMat2):-1:1
%     [year,mon,day,hr,minute,sec]=datevec(dateTimeNew(i));
%     newMat2(i,2) = year;
%     newMat2(i,3) = mon;
%     newMat2(i,4) = day;
%     newMat2(i,5) = hr;
%     newMat2(i,6) = minute;
%     newMat2(i,7) = sec;
% end

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

for i=1:size(newMat2,1)
    % station yyyy mon day hr min sec lat lon heading Wt sal wind wdir cloud waveht pitch roll
    fprintf(fidOut,'%.1f,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%03d,%.1f,%.2f,%.1f,%03d,%d,%.1f,%.2f,%.2f\n',newMat2(i,:));
end

fclose(fidOut);


