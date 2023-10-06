% This is not a HyperSAS/pySAS cruise, but use this to ingest the ancillary
% spreadsheets anyway. No need for SeaBASS output here. Output Matlab
% structure to the metadata directory

wipe

% Setup
campaign = 'ArcticCC'; % Not yet a designated SeaBASS name, but...
basePath = fullfile(filesep,'Users','daurin','Projects','HyperPACE');
inFile1 = fullfile(basePath,'field_data','metadata',campaign,'June_2023','ArcticCarbonCycle_ArcticCC_YukonDelta_SBA_Radiometry_Field_Log.xlsx');
outPath = fullfile(basePath,'field_data','metadata',campaign,'June_2023');

for cruises={'Alakanuk'}
    cruise = char(cruises);
    metadata = struct();
    %% Combined spreadsheet frome Blake (Alakanuk) and Scott (Norton Sound)
    [anc_data, anc_txt, anc_raw] = xlsread(inFile1, 'Sheet1');    

    if strcmpi(cruise,'Alakanuk')        
        anc_txt(1:6,:) = []; % strip off header

        for i=1:size(anc_data,1)
            fname = strrep(anc_txt(i,2),'"','');
            fname = strrep(fname{1},"'",'');
            fname = strrep(fname{1}," ",'');
            metadata(i).filename = fname;
            metadata(i).station = anc_data(i,1);
            metadata(i).dateTimeStart = datetime( datenum2datetime( (anc_data(i,3)+ 693960)), 'timezone','UTC'); % to matlab datenum
            metadata(i).dateTimeStop = datetime( datenum2datetime( (anc_data(i,4)+ 693960)), 'timezone','UTC'); % to matlab datenum
            metadata(i).latitude = anc_data(i,5);
            metadata(i).longitude = anc_data(i,6);
            metadata(i).wind = anc_data(i,8); % m/s
            metadata(i).waves = anc_data(i,10); % m/s
            metadata(i).cloud = anc_data(i,11)*100; % percent

        end
    else
        % Only one file per station (not all stations have SBA)
        anc_txt(1:4,:) = []; % header
        i=0;
        for n=1:size(anc_data,1)
%             if ~strcmpi(anc_txt(n,3),'N/A')
%                 i=i+1;
%                 metadata(i).filename = {[anc_txt{n,3} '.raw']};
%                 metadata(i).station = anc_data(n,1);
%                 
%                 a = num2str(anc_data(n,4));
%                 year = str2double(a(1:4));
%                 mon = str2double(a(5:6));
%                 day = str2double(a(7:8));
%                 metadata(i).dateTimeStart = ...
%                     datetime(year,mon,day,floor(24*anc_data(n,6)),...
%                     round(60*(24*anc_data(n,6)-floor(24*anc_data(n,6)))),0,'timezone','UTC');
%                 a = num2str(anc_data(n,5));
%                 mon = str2double(a(5:6));
%                 day = str2double(a(7:8));
%                 metadata(i).dateTimeStop = ...
%                     datetime(year,mon,day,floor(24*anc_data(n,7)),...
%                     round(60*(24*anc_data(n,7)-floor(24*anc_data(n,7)))),0,'timezone','UTC');
%                 metadata(i).latitude = mean( [anc_data(n,8) anc_data(n,10)] ); % Average start/stop
%                 metadata(i).longitude = mean( [anc_data(n,9) anc_data(n,11)] );
%                 metadata(i).cloud = anc_data(n,12); % percent
%                 metadata(i).wind = anc_data(n,14); % m/s
%                 metadata(i).waves = anc_data(n,15); % m
% 
%             end
        end
    end

    save([outPath filesep cruise '_metadata.mat'],"metadata")

end

% 
% %% Output
% 
% fidIn = fopen(inHeader,'r');
% fidOut = fopen(outFile,'w');
% 
% line = '';
% while ~contains(line,'end_header')
%     line = fgetl(fidIn);
%     fprintf(fidOut,'%s\n',line);
% end
% fclose(fidIn);
% 
% % Available:
% % stn year month day hour minute sec lat lon(9) SOG wind sst sss(13) cloud(14) seas(15)
% %
% %   SOG is not permissible in SeaBASS
% newDataMat(:,10) = [];
% 
% for i=1:size(newDataMat,1)
%     % sta year mon day hour min sec lat lon wind sst sss cloud seas
%     fprintf(fidOut,'%d,%d,%02d,%02d,%02d,%02d,%02d,%.4f,%.4f,%.1f,%.2f,%.2f,%.1f,%.1f\n',...
%         newDataMat(i,:));
% end
% 
% fclose(fidOut);