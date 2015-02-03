% Input file names to be processed
days = textread('C:\LickoMeterTemp\days5.txt','%f','delimiter','\n','whitespace',''); %#ok<*DTXTRD>
out_files = textread('C:\LickoMeterTemp\files7.txt','%s','delimiter','\n','whitespace','');

% Define destination folder
destination= 'C:\LickoMeterTemp\'; %pwd is current folder
% Assign constants 
mincontact=textread('C:\LickoMeterTemp\mincontact.txt','%f','delimiter','\n','whitespace','');%;30; %determines the length of time (of 1s) being ignored. Also lower limit of 1s in contact. Determines if lick or not
maxcontact=textread('C:\LickoMeterTemp\maxcontact.txt','%f','delimiter','\n','whitespace','');%130; %upper limit of 1s in contact. Determines if lick or not
minnocontact=textread('C:\LickoMeterTemp\minnoncontact.txt','%f','delimiter','\n','whitespace','');%50; %lower limit of 0s following contact. Determines if lick or not
maxnocontact=textread('C:\LickoMeterTemp\maxnoncontact.txt','%f','delimiter','\n','whitespace','');%150; %edit event to change time interval of 0s that determines end of event. Also upper limit of 0s following contact
boutdeterminant=textread('C:\LickoMeterTemp\bout.txt','%f','delimiter','\n','whitespace','');%5000; %edit bout to change time interval of 0s that determines end of bout
ms=textread('C:\LickoMeterTemp\ms.txt','%f','delimiter','\n','whitespace','');%3; %number of licks that determines microstructure
nSw=6; % Number of switches
after_lick_assumption=75; %when there are more than 150 0s after a lick, just looks at lick and following 150 0s
%%
% Make sure all imports are .txt files and exist
for q=1:length(out_files)
current_file_name=out_files{q};
if strcmp(current_file_name(end-3:end),'.txt')==0 
    error('All imported files must be text files');
elseif exist(current_file_name,'file')==0
    error('All imported files must exist. Check name of file.')
end
end

% Make sure days and out_files match up
if length(out_files)~=length(days)
    error('out_files and days must be the same length. See comment for "days"')
end

% Create one giant for loop so that multiple files can be run at once
for q=1:length(out_files)
    
%Create file directories
current_file_name=out_files{q};
current_file_delim=strsplit(current_file_name,'\');
justfilename=current_file_delim{end};
cfnNoTxt=justfilename(1:length(justfilename)-4);
out_folder=sprintf('%s\\%s',destination,cfnNoTxt);
if exist(destination,'dir')~=7;
mkdir(destination);
end
if exist(out_folder,'dir')==7
rmdir(out_folder,'s');
end
mkdir(out_folder);
    
% Read data. Edit file name to change data file being read.
data = dlmread(current_file_name, ' '); 

% Create files to write to 
% Note that this will delete existing files with the same name 
% Switch1 will correspond to the most significant digit in the binary data 
% Loop through each data entry 
for id = 1:nSw
%Create switch directories
switch_folder=sprintf('%s\\Switch%.f',out_folder,id);
msfolder=sprintf('%s\\Microstructure Graphs',switch_folder);
mkdir(switch_folder);
mkdir(msfolder);
%Start reading data
mask = data(:,1) == id;
data1 = data(mask, 2:3);
BufMat = [0,0];
if size(data1,1) > 1
for sw = 1:(size(data1,1) - 1)
    if data1(sw+1,1) == data1(sw,1);
        error('There are two 0s or two 1s in a row');
    end
    timediff = data1(sw+1,2) - data1(sw,2);
    if data1(sw,1) == 1
        BufMat(end,1) = timediff;
    else
        BufMat(end,2) = timediff;
        BufMat = [BufMat;0,0];
    end
end
end
BufMat=floor(BufMat/10000);

bufmat3=zeros(size(BufMat,1),1);
for bufrow=1:size(BufMat,1);
    bufmat3(bufrow,1)=sum(sum(BufMat(1:bufrow-1,:)))+1;
end
BufMat3=[BufMat,bufmat3];
BufMat4=[BufMat3;0,0,sum(BufMat3(end,:))];

%Write BufMat to xls file
BufMat_file=sprintf('%s\\BufMat%.f.xls',switch_folder,id);
warning('off','MATLAB:xlswrite:AddSheet');
xlswrite(BufMat_file,BufMat3, 'w');

%%
%Recreating data so that it accounts for buffer
sizeData=sum(sum(BufMat(:,:)));
BufDat=zeros(sizeData,1);
numpos=1;
for f=1:size(BufMat,1)
for g=numpos:numpos+BufMat(f,1)-1
BufDat(g,1)=1;
end
numpos=numpos+BufMat(f,1)+BufMat(f,2);
end

%Create data matrix containing bout interpretations
PosBout=[find(BufMat(:,2)>=boutdeterminant),size(BufMat,1)];
if size(PosBout,1)<1
    PosBout=[1,size(BufMat,1)]; %#ok<*NBRAK>
end
if PosBout(1)>1
    PosBout=[0;PosBout];            %#ok<*AGROW> %Starts bout1 at beginning if doesnt start with >5000 noncontact
end
if PosBout(end)>size(BufMat,1)
    PosBout=PosBout(1:(end-1),:); %make sure it always includes final bout
end
data3=[];           %data3 will store the values for bout interpretations
data4=[];           %data4 will store the values for microstructure interpretations
Optimal={};
for i=1:length(PosBout)-1
a=sum(sum(BufMat(1:PosBout(i),:)));           %Position of bout
b=BufMat(PosBout(i+1),1)+sum(sum(BufMat((PosBout(i)+1):(PosBout(i+1)-1),:)))+after_lick_assumption;       %Total bout time
c=sum(BufMat((PosBout(i)+1):(PosBout(i+1)),1));                 %Total contact time
d=PosBout(i+1)-PosBout(i);              %Number of tongue contacts
e=0;e1=0;f=0;
MSPos=[];         %mschart will store locations of microstructures' start and end, with respect to BufMat
MSLicksInBout=[];
for j=PosBout(i)+1:PosBout(i+1);
if BufMat(j,2)>=minnocontact && BufMat(j,1)<=maxcontact             
    e=e+1;                               %Number of licks increases by one
    if BufMat(j,2)<=maxnocontact
        e1=e1+1;                         %Lick counter increases by 1
        if e1==1
            posms=sum(sum(BufMat(1:j-1,:)));  %This is the position of the first lick in case microstructure exists
            MSstart=j;
        end
    else
        if e1>=(ms-1)                        %In this case, we have a enough licks, but it's interrupted by too many zeroes to continue microstructure
            MSPos=[MSPos;MSstart,j-1];  %j-1 if you want to ignore last lick with >150 ms off-contact
        end
        e1=0;
    end
else
    if e1>=ms
        MSPos=[MSPos;MSstart,j-1];
    end
    e1=0;
end
if BufMat(j,2)>maxnocontact
    f=f+1;                               %Number of events (0s too long)
end
end
%min max and std of contacts
contacts=BufMat(PosBout(i)+1:PosBout(i+1),1);
minimum=min(contacts(:));
maximum=max(contacts(:));
standarddev=std(contacts(:));
average=mean(contacts(:));
g=size(MSPos,1);
h=BufMat(PosBout(i+1),2)-after_lick_assumption;                %Time to next bout
data3=[data3;a,b,c,b-c,d,average,minimum,maximum,standarddev,e,f,g,h,0,0,0,0,0,0,0,0,0,0]; 

data5=[];
for m=1:size(MSPos,1)
%Chart of Microstructure Interpretations
    z=sum(sum(BufMat(1:MSPos(m,1)-1,:)));
    y=MSPos(m,2)-MSPos(m,1)+1;
    x=sum(BufMat(MSPos(m,1):MSPos(m,2),1))/y;
    w=sum(BufMat(MSPos(m,1):MSPos(m,2),2))/y;
    v=sum(sum(BufMat(MSPos(m,1):MSPos(m,2),:)));
    if BufMat(MSPos(m,2),2)>after_lick_assumption
        v=v-BufMat(MSPos(m,2),2)+after_lick_assumption;
        w=(sum(BufMat(MSPos(m,1):MSPos(m,2),2))-BufMat(MSPos(m,2),2)+150)/y;
    end
    data4=[data4;i,z,y,x,w,v];% Plotting Lick Microstructures
    data5=[data5;i,z,y,x,w,v];
    f1=figure(2);set(f1,'visible','off');
%    fprintf(sprintf('Microstructure exists %.f time(s) in bout %.f of switch %.f of file %s\n',data3(i,8),i,id,out_files{q}))
    step=.001;
    x_axis = z*step:step:(z+v)*step;
    y_axis = BufDat(z:z+v);
    bar(x_axis,y_axis);
    xlabel('time (seconds)');
    ylabel('licks');
    saveas(f1,sprintf('%s\\Bout%.f Microstructure%.f.png',msfolder,i,m));
    close('all');
end

%Optimal spreadsheet
sizeofoptimal=size(Optimal,1);                      %records location where last ms data ended
for opt=1:size(MSPos,1)
    MSLicksInBout=[MSLicksInBout;(BufMat3(MSPos(opt,1):MSPos(opt,2),1:3))];
    Optimal=[Optimal;num2cell(zeros((MSPos(opt,2)-MSPos(opt,1)+1),5)),num2cell((BufMat3(MSPos(opt,1):MSPos(opt,2),1:3)))];              %creates new rows for the comprehensive chart
    for optim=(sizeofoptimal+1):size(Optimal,1)
    Optimal(optim,1:5)=[id,{sprintf('Day %.f %s',q,cfnNoTxt)},i,size(data5,1),(optim-(sizeofoptimal))];        %replaces zeroes for new bout microstructure rows
    end
end
if size(MSLicksInBout,1)>0
data3(i,14:23)=[size(MSLicksInBout,1),mean(MSLicksInBout(:,1)),min(MSLicksInBout(:,1)),max(MSLicksInBout(:,1)),std(MSLicksInBout(:,1)),mean(MSLicksInBout(:,2)),min(MSLicksInBout(:,2)),max(MSLicksInBout(:,2)),std(MSLicksInBout(:,2)),sum(MSLicksInBout(:))];
end
end

MSavg=num2cell(zeros(1,5));
if size(data4,1)>0
    col_header={'Start location (ms)','Number of licks','Average contact time (ms)','Average off time (ms)','Length (ms)'};
    row_header={};
    for k=1:size(data4,1)
    row_name=sprintf('Bout%.f', data4(k,1));
    row_header(k,1)={row_name}; %#ok<*SAGROW>
    end
    MSavg=[{0},(sum(data4(:,3))/size(data4,1)),(sum(data4(:,4).*data4(:,3))/sum(data4(:,3))),(sum(data4(:,5).*data4(:,3))/sum(data4(:,3))),(sum(data4(:,6))/size(data4,1))];
    MSdata_cells=num2cell(data4(:,2:end));
    MSoutput_matrix=[{' '} col_header;row_header MSdata_cells;{'Average'} MSavg];
    xlswrite(sprintf('%s\\Chart%.f Microstructure',switch_folder,id),MSoutput_matrix, 'w');           %writes interpretations for each microstructure found in this bout
end

Tot=num2cell(zeros(1,23));Avg=num2cell(zeros(1,23));
if size(data3,1)>0
data3nonzero=data3(data3(:,14)>0,14:23);
if sum(data3(:,14))==0
    data3nonzero=zeros(1,10);
end
Tot=[{' '},{sum(data3(:,2))},sum(data3(:,3)),sum(data3(:,4)),sum(data3(:,5)),{' '},min(data3(:,7)),max(data3(:,8)),{' '},sum(data3(:,10)),sum(data3(:,11)),sum(data3(:,12)),{' '},sum(data3(:,14)),{' '},min(data3nonzero(:,3)),max(data3(:,17)),{' '},{' '},min(data3nonzero(:,7)),max(data3(:,21)),{' '},sum(data3(:,23))];
Avg=[{' '},{sum(data3(:,2))./size(data3,1)},sum(data3(:,3))./size(data3,1),sum(data3(:,4))./size(data3,1),sum(data3(:,5))./size(data3,1),sum(data3(:,3))./sum(data3(:,5)),sum(data3(:,7))./size(data3,1),sum(data3(:,8))./size(data3,1),{' '},sum(data3(:,6))./size(data3,1),sum(data3(:,7))./size(data3,1),sum(data3(:,8))./size(data3,1),{' '},mean(data3nonzero(:,1))./size(data3nonzero,1),mean(data3nonzero(:,2))./size(data3nonzero,1),mean(data3nonzero(:,3))./size(data3nonzero,1),mean(data3nonzero(:,4))./size(data3nonzero,1),{' '},mean(data3nonzero(:,6))./size(data3nonzero,1),mean(data3nonzero(:,7))./size(data3nonzero,1),mean(data3nonzero(:,8))./size(data3nonzero,1),{' '},mean(data3nonzero(:,10))./size(data3nonzero,1)];

if size(Optimal,1)>0
Optimal_file=sprintf('%s\\Optimal%.f.xls',switch_folder,id);
warning('off','MATLAB:xlswrite:AddSheet');
xlswrite(Optimal_file,Optimal,4);
end

% Plotting Contacts per Bout
f1=figure(1);set(f1,'visible','off');
i = 1:size(data3,1);
bar(i, data3(:,4));
xlabel('bout');
ylabel('number of contacts');
saveas(f1,sprintf('%s\\Plot%.f Contacts_per_Bout.png',switch_folder,id))
close('all');

% Plotting Avg Contact Length per Bout
f1=figure(1);set(f1,'visible','off');
i = 1:size(data3,1);
bar(i, data3(:,5));
xlabel('bout');
ylabel('avg time of contact');
saveas(f1,sprintf('%s\\Plot%.f Avg_Contact_Length_per_Bout.png',switch_folder,id))
close('all');
end

% %Write boutinfo data interpretations to xls file
% data_cells=num2cell(data3);
% col_header=[{'Bout';sprintf('Bouts are groups of contacts and non-contacts separated by any period of non-contact over %.f milliseconds (ms)',boutdeterminant)},{'Position';'Tells when the bout starts in ms starting from the beginning of the file, in milliseconds (ms)'},{'Duration';'Total duration of bout in ms'},{'Tot cont time';'Sum of durations of every contact within each bout. A contact is any time period where the lickometer is turned on'},{'Tot non-cont time (ms)';'Adds up durations of every non-contact within each bout'}];
%     col_header=[col_header,{'# contacts';'Counts the total number of contacts in each bout, which will be equal to the number of non-contacts'},{'Avg cont time';'The mean duration of contacts in the bout'},{'Min cont time';' Minimum duration of any contact in the bout'},{'Max cont time';'Maximum duration of any contact in the bout'},{'Std contact time';'Calculated standard deviation of all contacts within the bout'},{'# licks';sprintf('Licks are defined as a contact with a duration between %.f and %.f ms followed by non-contact with a duration between %.f and %.f ms',mincontact,maxcontact,minnocontact,maxnocontact)}];
%     col_header=[col_header,{'# events';sprintf('An event is any group of contacts separated by less than %.f ms non-contact',maxnocontact)},{'Microstructure';sprintf('Gives the number of occurences of microstructure in the bout. Microstructure is a cluster of %.f or more consecutive licks, licks being defined under "Number of licks"',ms)},{'Time to next bout';'Tells the duration of non-contact until the next bout begins'},{'# Microstr licks';'Total number of licks that exist within microstructures of given bout'},{'Avg contact';'Average contact time of microstructure licks'},{'Min contact';'Minimum contact time of microstructure licks'}];
%     col_header=[col_header,{'Max contact';'Maximum contact time of microstructure licks'},{'SD contact';'Standard deviation of contact times of microstructure licks'},{'Avg non-contact';'Average non-contact time of microstructure licks'},{'Min non-contact';'Minimum non-contact time of microstructure licks'},{'Max non-contact';'Maximum non-contact time of microstructure licks'},{'SD non-contact';'Standard deviation of non-contact time of microstructure licks'},{'Tot microstr time';'Gives total duration of microstructures in bout'}];
% row_header={};
% for k=1:size(data3,1)
% row_name=sprintf('Bout%.f', k);
% row_header(k,1)={row_name}; %#ok<*SAGROW>
% end
% topRow={sprintf('Lick: %.f<contact<%.f ... %.f<nonctonact<%.f, bouts are separated by %.f ms non-contact time, %.f consecutive licks is considered microstructure',mincontact,maxcontact,minnocontact,maxnocontact,boutdeterminant,ms),' ',cfnNoTxt,' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' '};
% output_matrix=[topRow;col_header;row_header,data_cells;{'Total'},Tot;{'Average'},Avg]; 
% bout_file=sprintf('%s\\Bout_info%.f.xls',switch_folder,id);
% xlswrite(bout_file,output_matrix, 'w');

% Plotting Licks over Time
%f1=figure(1);set(f1,'visible','off');
%step = 1/3600000; %1/1000 for seconds, 1/60000 for minutes, 1/3600000 for hours
%i = 1*step:step:sizeData*step;
%area(i, BufDat(:,1));
%xlabel('time (hours)');
%ylabel('contact');
%saveas(f1,sprintf('%s\\Plot%.f Raw.png',switch_folder,id))
%close('all');

if size(data4,1)>0
% Plotting Licks per MS
f1=figure(1);set(f1,'visible','off');
i = 1:size(data4,1);
bar(i, data4(:,3));
xlabel('Microstructure');
ylabel('Number of licks');
saveas(f1,sprintf('%s\\Plot%.f Length of Microstructures.png',switch_folder,id))
close('all');

% Plotting nature of each MS
f1=figure(1);set(f1,'visible','off');
j = [data4(:,4),data4(:,5)];
if size(j,1)<2
    j=[j;0,0];
end
bar(j,'hist');
legend('Avg contact time','Avg after-contact time');
xlabel('Microstructure');
ylabel('Time');
saveas(f1,sprintf('%s\\Plot%.f Microstructure_Nature.png',switch_folder,id));
close('all');  
end

Trend=zeros(1,10,nSw);                  %Will keep track of plottable values for each piece of data
hpd=sum(BufMat3(end,:))/3600000;    %Hours per day
Trend(1,1,id)=days(q);                  %Day
Trend(1,2,id)=size(data3,1)/hpd;        %Number of bouts per hour for current switch and day
Trend(1,3,id)=Avg{6};                   %Avg length of contacts
Trend(1,4,id)=MSavg{2};                 %Number of licks in MS
Trend(1,5,id)=MSavg{3};                 %Time of contact per lick in microstructure
Trend(1,6,id)=MSavg{4};                 %Time of noncontact per lick
Trend(1,7,id)=Tot{10}/hpd;              %Number of licks per hour
Trend(1,8,id)=Tot{5}/hpd;               %Number of contacts per hour
Trend(1,9,id)=Avg{10};                  %Number of licks per bout
Trend(1,10,id)=Avg{5};                  %Number of contacts per bout

%Create trend folder directories
Filename={'Bouts per hour','Avg length of contacts','Avg Number of Licks per Microstructure','Microstructure Contact vs Non-Contact time (ms)',0,'Total Licks vs Contacts per hour',0,'Licks vs Contacts per bout'};
TrendData_file=sprintf('%s\\Trend%.f_Data.xls',switch_folder,id);
TrendCells=[{'Day',Filename{1:3},'MicroStr contact time per lick','MicroStr non-contact time per lick','Tot licks','Tot contacts','Licks per bout','Contact per bout'};num2cell(Trend(:,:,id))];
xlswrite(TrendData_file,TrendCells,4);
end
end