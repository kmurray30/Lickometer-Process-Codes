% Input file names to be processed
days = (1);%textread('C:\LickoMeterTemp\days.txt','%f','delimiter','\n','whitespace',''); %#ok<*DTXTRD>
out_files = {'Test2.txt'};%textread('C:\LickoMeterTemp\files.txt','%s','delimiter','\n','whitespace','');

%out_files1={'out_0103_6pm.txt','out_0104_6pm.txt','out_0105_3pm.txt','out_0106_6pm.txt','out_0107_3pm.txt'};
%days=[1,2];                   %Give the distance between days for graphing purposes. Ex. if the days are Jan 7, Jan 8, Jan 10, and Jan 13, then days={1,2,4,7}

% Define destination folder
destination= 'C:\LickoMeterTemp\'; %pwd is current folder
%current_file_name='D:\GTech\lickometer\data\out_0103_6pm.txt';
%ff=strcmp(current_file_name(end-3:end),'.txt');
% Assign constants 
mincontact= 30;%textread('C:\LickoMeterTemp\mincontact.txt','%f','delimiter','\n','whitespace','');%;30; %determines the length of time (of 1s) being ignored. Also lower limit of 1s in contact. Determines if lick or not
maxcontact= 130;%textread('C:\LickoMeterTemp\maxcontact.txt','%f','delimiter','\n','whitespace','');%130; %upper limit of 1s in contact. Determines if lick or not
minnocontact= 50;%textread('C:\LickoMeterTemp\minnoncontact.txt','%f','delimiter','\n','whitespace','');%50; %lower limit of 0s following contact. Determines if lick or not
maxnocontact= 150;%textread('C:\LickoMeterTemp\maxnoncontact.txt','%f','delimiter','\n','whitespace','');%150; %edit event to change time interval of 0s that determines end of event. Also upper limit of 0s following contact
boutdeterminant= 5000;%textread('C:\LickoMeterTemp\bout.txt','%f','delimiter','\n','whitespace','');%5000; %edit bout to change time interval of 0s that determines end of bout
ms= 3;%textread('C:\LickoMeterTemp\ms.txt','%f','delimiter','\n','whitespace','');%3; %number of licks that determines microstructure
nSw=6; % Number of switches
after_lick_assumption=150; %when there are more than 150 0s after a lick, just looks at lick and following 150 0s
bin='bout';
bintime=60000;
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
    
%Create file directories
current_file_name=out_files{q};
current_file_delim=strsplit(current_file_name,'\');
justfilename=current_file_delim{end};
cfnNoTxt=justfilename(1:length(justfilename)-4);
out_folder=sprintf('%s\\%s',destination,cfnNoTxt);
if exist(destination,'dir')~=7;
mkdir(destination,'s');
end
if exist(out_folder,'dir')==7
rmdir(out_folder,'s');
end
mkdir(out_folder);
    
% Read data. Edit file name to change data file being read.
data = dlmread(current_file_name, ' '); 

%mpe=(data(end,2)-data(1,2))/size(data,1); %milliseconds per entry
%if data(end,2)-data(1,2)<0
%    error('Error with timestamp. Please check text files. The last timestamp should be greater than the first.');
%end
mpe=11.27;
if size(data,1)<boutdeterminant
    error('Text file is smaller than bout size. Either reduce length of bout or import a larger file.');
end
buf=round(mincontact/mpe); %edit buf to change the maximum length of a sequence of 1s or 0s that will be ignored

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
loc0=0; %#ok<*NASGU>
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

%Create BufMat3 which is BufMat with a third position column
bufmat3=zeros(size(BufMat,1),1);
for bufrow=1:size(BufMat,1);
    bufmat3(bufrow,1)=sum(sum(BufMat(1:bufrow-1,:)))+1;
end
BufMat3=[BufMat,bufmat3];
BufMat4=[BufMat3;0,0,sum(BufMat3(end,:))];

%Create data matrix containing bout interpretations
if strcmp(bin,'bout')
    PosBout=find(BufMat(:,2)>=boutdeterminant);
elseif strcmp(bin,'time')
    PosBout=[];
    for binlength=1:floor(size(BufDat,1)./bintime)
        binstartcurrent=find(BufMat4(:,3)>=(bintime.*binlength));
        PosBout=[PosBout;binstartcurrent(1,1)];
    end
else
    error('bin must be either "bout" or "time"');
end
if size(PosBout,1)<1
    PosBout=[1]; %#ok<*NBRAK>
end
if PosBout(1)>1
    PosBout=[1;PosBout];            %#ok<*AGROW> %make sure it always starts bout1 at 1
end
if PosBout(end)>size(BufMat,1)
    PosBout=PosBout(1:(end-1),:); %make sure it always includes final bout
end
data3=[];           %data3 will store the values for bout interpretations
data4=[];           %data4 will store the values for microstructure interpretations
Optimal=[];
for i=1:length(PosBout)-1
a=sum(sum(BufMat(1:PosBout(i),:)));           %Position of bout
b=BufMat(PosBout(i+1),1)+sum(sum(BufMat((PosBout(i)+1):(PosBout(i+1)-1),:)))+after_lick_assumption;       %Total bout time
c=sum(BufMat((PosBout(i)+1):(PosBout(i+1)),1));                 %Total contact time
d=PosBout(i+1)-PosBout(i);              %Number of tongue contacts
e=0;e1=0;f=0;
MSchart=[];         %mschart will store locations of microstructures' start and end, with respect to BufMat
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
            MSchart=[MSchart;MSstart,j-1];  %j-1 if you want to ignore last lick with >150 ms off-contact
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

data5=[];
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
for opt=1:size(MSchart,1)
    Optimal=[Optimal;zeros((MSchart(opt,2)-MSchart(opt,1)+1),5),(BufMat(MSchart(opt,1):MSchart(opt,2),1:2))];              %creates new rows for the comprehensive chart
    for optim=(sizeofoptimal+1):size(Optimal,1)
    Optimal(optim,1:5)=[id,q,i,(optim-(sizeofoptimal)),size(data5,1)];        %replaces zeroes for new bout microstructure rows
    end
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

if size(data3,1)>0
tot=[0,{sum(data3(:,2))},sum(data3(:,3)),sum(data3(:,4)),sum(data3(:,3))./sum(data3(:,4)),sum(data3(:,6)),sum(data3(:,7)),sum(data3(:,8)),0];
avg=[0,{sum(data3(:,2))./size(data3,1)},sum(data3(:,3))./size(data3,1),sum(data3(:,4))./size(data3,1),sum(data3(:,3))./sum(data3(:,4)),sum(data3(:,6))./size(data3,1),sum(data3(:,7))./size(data3,1),sum(data3(:,8))./size(data3,1),0];

%Write BufMat to xls file
BufMat_file=sprintf('%s\\BufMat%.f.xls',switch_folder,id);
warning('off','MATLAB:xlswrite:AddSheet');
xlswrite(BufMat_file,BufMat3, 'w');

if size(Optimal,1)>0
Optimal_file=sprintf('%s\\Optimal%.f.xls',switch_folder,id);
warning('off','MATLAB:xlswrite:AddSheet');
xlswrite(Optimal_file,Optimal, 'w');
end

%Write data interpretations to xls file
data_cells=num2cell(data3);
col_header={'Bout position (ms)','Total bout time (ms)','Total contact time (ms)','Number of tongue contacts','Average contact time','Number of licks', 'Number of events', 'Microstructure?', 'Time to next bout'};
row_header={};
for k=1:size(data3,1)
row_name=sprintf('Bout%.f', k);
row_header(k,1)={row_name}; %#ok<*SAGROW>
end
output_matrix=[{' '} col_header; row_header data_cells; {'Total'}, tot; {'Average'}, avg]; 
bout_file=sprintf('%s\\Bout info%.f.xls',switch_folder,id);
xlswrite(bout_file,output_matrix, 'w');

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

hpd=(data(end,2)-data(1,2))/3600000;    %Hours per day
Trend(q,1,id)=days(q);                  %Day
Trend(q,2,id)=size(data3,1)/hpd;        %Number of bouts per hour for current switch and day
Trend(q,3,id)=tot{5};                   %Avg length of contacts
Trend(q,4,id)=MSavg{2};                 %Number of licks in MS
Trend(q,5,id)=MSavg{3};                 %Time of contact per lick in microstructure
Trend(q,6,id)=MSavg{4};                 %Time of noncontact per lick
Trend(q,7,id)=tot{6}/hpd;               %Number of licks per hour
Trend(q,8,id)=tot{4}/hpd;               %Number of contacts per hour
Trend(q,9,id)=avg{6};                   %Number of licks per bout
Trend(q,10,id)=avg{4};                  %Number of contacts per bout
end
end

%Create trend folder directories
Filename={'Bouts per hour','Avg length of contacts','Avg Number of Licks per Microstructure','Microstructure Contact vs Non-Contact time (ms)',0,'Total Licks vs Contacts per hour',0,'Licks vs Contacts per bout'};
TrendData_file=sprintf('%s\\Trend%.f_Data.xls',switch_folder,id);
TrendCells=[{'Day',Filename{1:3},'MicroStr contact time per lick','MicroStr non-contact time per lick','Tot licks','Tot contacts','Licks per bout','Contact per bout'};num2cell(Trend(:,:,id))];
xlswrite(TrendData_file,TrendCells, 'w');