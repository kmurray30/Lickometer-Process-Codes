% Input file names to be processed

days = textread('C:\LickoMeterTemp\days.txt','%f','delimiter','\n','whitespace','');
out_files = textread('C:\LickoMeterTemp\files.txt','%s','delimiter','\n','whitespace','');

%out_files1={'out_0103_6pm.txt','out_0104_6pm.txt','out_0105_3pm.txt','out_0106_6pm.txt','out_0107_3pm.txt'};
%days=[1,2];                   %Give the distance between days for graphing purposes. Ex. if the days are Jan 7, Jan 8, Jan 10, and Jan 13, then days={1,2,4,7}

% Define destination folder
destination= pwd; %pwd is current folder
%current_file_name='D:\GTech\lickometer\data\out_0103_6pm.txt';
%ff=strcmp(current_file_name(end-3:end),'.txt');
% Assign constants 
mincontact=30; %determines the length of time (of 1s) being ignored. Also lower limit of 1s in contact. Determines if lick or not
maxcontact=130; %upper limit of 1s in contact. Determines if lick or not
minnocontact=50; %lower limit of 0s following contact. Determines if lick or not
maxnocontact=150; %edit event to change time interval of 0s that determines end of event. Also upper limit of 0s following contact
bout=5000; %edit bout to change time interval of 0s that determines end of bout
ms=3; %number of licks that determines microstructure
nSw=6; % Number of switches
after_lick_assumption=150; %when there are more than 150 0s after a lick, just looks at lick and following 150 0s
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

Trend=zeros(size(out_files,1),5,nSw); %Will keep track of plottable values for each piece of data

% Create one giant for loop so that multiple files can be run at once
for q=1:length(out_files)
current_file_name=out_files{q};
    
% Read data. Edit file name to change data file being read.
data = dlmread(current_file_name, ' '); 

mpe=(data(end,2)-data(1,2))/size(data,1); %milliseconds per entry
buf=round(mincontact/mpe); %edit buf to change the maximum length of a sequence of 1s or 0s that will be ignored

% Create files to write to 
% Note that this will delete existing files with the same name 
% Switch1 will correspond to the most significant digit in the binary data 
% Loop through each data entry 
for id = 1:nSw
A=[zeros(size(data,1),1),data(:,2)];
for i = 1:size(data,1)
swStr=sprintf('%.d',data(i,1));
if nSw+1-id <= length(swStr)
    if swStr(length(swStr)-nSw+id)=='1'
        A(i,1)=1;
    end
end
end 

BufMat=zeros(1,2);
r=1;
c=2;
ons=0;
zeds=0;
loc0=0;
loc1=0;
for i = 1:size(A, 1)-1
if A(i, 1)==0
    zeds=zeds+1;
    if A(i+1, 1)==1
        loc1=i+1;
        if A(loc1:loc1+buf-1,1)==ones(buf,1)
            if c==2
                BufMat(r,c)=zeds+ons;
                zeds=0;
                ons=0;
                c=1;
                r=r+1;
            end
        end
    end
elseif A(i, 1)==1
    ons=ons+1;
    if A(i+1, 1)==0
        loc0=i+1;
        if A(loc0:loc0+buf-1,1)==zeros(buf,1)
            if c==1
                BufMat(r,c)=ons+zeds;
                ons=0;
                zeds=0;
                c=2;
            end
        end
    end
end
end
BufMat(end,2)=zeds+ons+1;
BufMat=floor(BufMat*mpe);

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

%Write BufMat to xls file
BufMat_file=sprintf('BufMat%.f.xls', id);
warning('off','MATLAB:xlswrite:AddSheet');
xlswrite(BufMat_file,BufMat, 'w');

%Create data matrix containing bout interpretations
PosBout=find(BufMat(:,2)>=bout);
if PosBout(1)>1
    PosBout=[1;PosBout];            %#ok<*AGROW> %make sure it always starts bout1 at 1
end
if PosBout(end)~=size(BufMat,1)
    PosBout=[PosBout;size(BufMat,1)]; %make sure it always includes final bout
end
data3=[];           %data3 will store the values for bout interpretations
data4=[];           %data4 will store the values for microstructure interpretations
for i=1:length(PosBout)-1
a=sum(sum(BufMat(1:PosBout(i),:)));           %Position of bout
b=BufMat(PosBout(i+1),1)+sum(sum(BufMat((PosBout(i)+1):(PosBout(i+1)-1),:)))+after_lick_assumption;       %Total bout time
c=sum(BufMat((PosBout(i)+1):(PosBout(i+1)),1));                 %Total contact time
d=PosBout(i+1)-PosBout(i);              %Number of tongue contacts
e=0;e1=0;f=0;
MSchart=[];         %mschart will store locations of microstructures' start and end, for each bout
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
            MSchart=[MSchart;MSstart,j];
        end
        e1=0;
    end
else
    if e1>=ms
        MSchart=[MSchart;MSstart,j-1];
    end
    e1=0;
end
if BufMat(j,2)>maxnocontact
    f=f+1;                               %Number of events (0s too long)
end
end
g=size(MSchart,1);
h=BufMat(PosBout(i+1),2)-after_lick_assumption;                %Time to next bout
data3=[data3;a,b,c,d,c/d,e,f,g,h];

for m=1:size(MSchart,1)

%Chart of Microstructure Interpretations
    z=sum(sum(BufMat(1:MSchart(m,1)-1,:)));
    y=MSchart(m,2)-MSchart(m,1)+1;
    x=sum(BufMat(MSchart(m,1):MSchart(m,2),1))/y;
    w=sum(BufMat(MSchart(m,1):MSchart(m,2),2))/y;
    v=sum(sum(BufMat(MSchart(m,1):MSchart(m,2),:)));
    if BufMat(MSchart(m,2),2)>after_lick_assumption
        v=v-BufMat(MSchart(m,2),2)+after_lick_assumption;
        w=(sum(BufMat(MSchart(m,1):MSchart(m,2),2))-BufMat(MSchart(m,2),2)+150)/y;
    end
    data4=[data4;i,z,y,x,w,v];% Plotting Lick Microstructures
    f1=figure(2);set(f1,'visible','off');
%    fprintf(sprintf('Microstructure exists %.f time(s) in bout %.f of switch %.f of file %s\n',data3(i,8),i,id,out_files{q}))
    step=.001;
    x_axis = z*step:step:(z+v)*step;
    y_axis = BufDat(z:z+v);
    bar(x_axis,y_axis);
    xlabel('time (seconds)');
    ylabel('licks');
    set(f1,'visible','on');
    saveas(f1,sprintf('Graph%.f Bout%.f Microstructure%.f.png',id,i,m));
    close('all');
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
    MSavg=[{sum(data4(:,2))/size(data4,1)},(sum(data4(:,3))/size(data4,1)),(sum(data4(:,4))/size(data4,1)),(sum(data4(:,5))/size(data4,1)),(sum(data4(:,6))/size(data4,1))];
    MSdata_cells=num2cell(data4(:,2:end));
    MSoutput_matrix=[{' '} col_header;row_header MSdata_cells;{'Average'} MSavg];
    xlswrite(sprintf('Chart%.f Microstructure',id),MSoutput_matrix, 'w');           %writes interpretations for each microstructure found in this bout
end

if size(data3,1)>0
tot=[0,{sum(data3(:,2))},sum(data3(:,3)),sum(data3(:,4)),sum(data3(:,3))./sum(data3(:,4)),sum(data3(:,6)),sum(data3(:,7)),0,0];
avg=[0,{sum(data3(:,2))./size(data3,1)},sum(data3(:,3))./size(data3,1),sum(data3(:,4))./size(data3,1),sum(data3(:,3))./sum(data3(:,4)),sum(data3(:,6))./size(data3,1),sum(data3(:,7))./size(data3,1),0,0];

%Write data interpretations to xls file
data_cells=num2cell(data3);
col_header={'Bout position (ms)','Total bout time (ms)','Total contact time (ms)','Number of tongue contacts','Average contact time','Number of licks', 'Number of events', 'Microstructure?', 'Time to next bout'};
row_header={};
for k=1:size(data3,1)
row_name=sprintf('Bout%.f', k);
row_header(k,1)={row_name}; %#ok<*SAGROW>
end
output_matrix=[{' '} col_header; row_header data_cells; {'Total'}, tot; {'Average'}, avg]; 
bout_file=sprintf('Bout info%.f.xls', id);
xlswrite(bout_file,output_matrix, 'w');

% Plotting Contacts per Bout
f1=figure(1);set(f1,'visible','off');
i = 1:size(data3,1);
bar(i, data3(:,4));
xlabel('bout');
ylabel('number of contacts');
set(f1,'visible','on');
saveas(f1,sprintf('Plot%.f Contacts_per_Bout.png',id))
close('all');

% Plotting Avg Contact Length per Bout
f1=figure(1);set(f1,'visible','off');
i = 1:size(data3,1);
bar(i, data3(:,5));
xlabel('bout');
ylabel('avg time of contact');
set(f1,'visible','on');
saveas(f1,sprintf('Plot%.f Avg_Contact_Length_per_Bout.png',id))
close('all');
end

% Plotting Licks over Time
%f1=figure(1);set(f1,'visible','off');
%step = 1/1000; %1/1000 for seconds, 1/60000 for minutes, 1/3600000 for hours
%i = 1*step:step:sizeData*step;
%bar(i, BufDat(:,1));
%xlabel('time (seconds)');
%ylabel('contact');
%set(f1,'visible','on');
%saveas(f1,sprintf('Plot%.f Raw.png',id))
%close('all');

if size(data4,1)>0
% Plotting Licks per MS
f1=figure(1);set(f1,'visible','off');
i = 1:size(data4,1);
bar(i, data4(:,3));
xlabel('Microstructure');
ylabel('Number of licks');
set(f1,'visible','on');
saveas(f1,sprintf('Plot%.f Length of Microstructures.png',id))
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
set(f1,'visible','on');
saveas(f1,sprintf('Plot%.f Microstructure_Nature.png',id))
close('all');  
end

Trend(q,1,id)=days(q);
Trend(q,2,id)=size(data3,1);    %Number of bouts per day for current switch and day
Trend(q,3,id)=tot{5};           %Avg length of contacts
Trend(q,4,id)=MSavg{2};         %Number of licks in MS
Trend(q,5,id)=MSavg{3};         %Time of contact per lick in microstructure
Trend(q,6,id)=MSavg{4};         %Time of noncontact per lick
Trend(q,7,id)=tot{6};           %Number of licks
Trend(q,8,id)=tot{4};           %Number of contacts
Trend(q,9,id)=avg{6};          %Number of licks per bout
Trend(q,10,id)=avg{4};          %Number of contacts per bout
end

%Organize files into appropriate folders
cfnNoTxt=current_file_name(1:length(current_file_name)-4);
out_folder=sprintf('%s\\%s',destination,cfnNoTxt);
try
if exist(out_folder,'dir')==7
rmdir(out_folder,'s');
end
mkdir(out_folder);
for id=1:nSw
try
switch_folder=sprintf('%s\\Switch%.f',out_folder,id);
msfolder=sprintf('%s\\Microstructure Graphs',switch_folder);
mkdir(switch_folder);
movefile(sprintf('BufMat%.f.xls',id),switch_folder);
movefile(sprintf('Bout info%.f.xls',id),switch_folder);
movefile(sprintf('Plot%.f*',id),switch_folder);
end
try %#ok<*TRYNC>
    mkdir(msfolder);
    movefile(sprintf('Graph%.f*',id),msfolder);
    movefile(sprintf('Chart%.f*',id),switch_folder);
end
end
end
end

Filename={'Number of bouts','Avg length of contacts','Avg Number of Licks per Microstructure','Microstructure Contact vs Non-Contact time (ms)',0,'Total Licks vs Contacts',0,'Licks vs Contacts per bout'};
for id=1:nSw
for u=2:4
    f1=figure(1);set(f1,'visible','off');
    i = days;
    bar(i, Trend(:,u,id));
    xlabel('Day');
    ylabel(Filename{u-1});
    set(f1,'visible','on');
    saveas(f1,sprintf('Trend%.f %s.png',id,Filename{u-1}));
    close('all');
end
for u=5:2:9
    f1=figure(1);set(f1,'visible','off');
    i = days;
    j = [Trend(:,u,id),Trend(:,u+1,id)];
    if size(j,1)<2
        j=[j;0,0]; %#ok<*AGROW>
        i=[i,0];
    end
    bar(i,j,'hist');
    names=strsplit(Filename{u-1},{' vs ',' per'});
    legend(' ',[names(1),names(2)]);
    xlabel('Day');
    ylabel(Filename{u-1});
    set(f1,'visible','on');
    saveas(f1,sprintf('Trend%.f %s.png',id,Filename{u-1}));
    close('all');
end
TrendData_file=sprintf('Trend%.f Data.xls', id);
TrendCells=[{'Day',Filename{1:3},'MicroStr contact time per lick','MicroStr non-contact time per lick','Tot licks','Tot contacts','Licks per bout','Contact per bout'};num2cell(Trend(:,:,id))];
xlswrite(TrendData_file,TrendCells, 'w');
end

%Organize files into trend folder
trend_folder=sprintf('%s\\Trends',destination);
try
if exist(trend_folder,'dir')==7
rmdir(trend_folder,'s');
end
mkdir(trend_folder);
for id=1:nSw
switch_folder=sprintf('%s\\Switch%.f',trend_folder,id);
mkdir(switch_folder);
movefile(sprintf('Trend%.f*',id),switch_folder);
end
end