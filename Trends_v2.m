% Input file names to be processed
days = textread('C:\LickoMeterTemp\days2.txt','%f','delimiter','\n','whitespace',''); %#ok<*DTXTRD>
out_files = textread('C:\LickoMeterTemp\files2.txt','%s','delimiter','\n','whitespace','');

destination= 'C:\LickoMeterTemp\';

nSw=6; % Number of switches

%Create trend folder directories
trend_folder=sprintf('%s\\Trends',destination);
if exist(trend_folder,'dir')==7
rmdir(trend_folder,'s');
end
mkdir(trend_folder);

Trend=zeros(length(days),10,nSw);
for sw=1:nSw
switch_folder=sprintf('%s\\Switch%.f',trend_folder,sw);
mkdir(switch_folder);
OptimalTmp=num2cell(zeros(0,7));
for f=1:length(days)
d=days(f);
cfnNoTxt=out_files{f};
Trend_file_name=sprintf('%s\\Switch%.f\\Trend%.f_Data',cfnNoTxt,sw,sw);
Trendrow=xlsread(Trend_file_name,4);
Trend(f,:,sw)=Trendrow(end,:);
Trend(f,1,sw)=d;
Optimal_file_name=sprintf('%s\\Switch%.f\\Optimal%.f.xls',cfnNoTxt,sw,sw);
[~,~,BoutInfoComp]=xlsread(sprintf('%s\\Switch%.f\\Bout_info%.f.xls',cfnNoTxt,sw,sw),4);
BoutInfoComp(1,2)={sprintf('Day %.f',d)};
xlswrite(sprintf('%s\\Switch%.f\\Cage%.fBout_info.xls',trend_folder,sw,sw),BoutInfoComp,f);
if exist(Optimal_file_name,'file')
[ndata,text,optdata]=xlsread(Optimal_file_name,4);
slashloc=strfind(cfnNoTxt,'\');
optdata=[optdata(:,1),num2cell(repmat(d,size(optdata,1),1)),repmat({cfnNoTxt(slashloc(end)+1:end)},size(optdata,1),1),optdata(:,3:end)];
OptimalTmp=[OptimalTmp;optdata];
end
end
OptimalTmpHeaders=[{'Cage'},{'Day'},{'File name'},{'Bout'},{'Number of Microstructures in bout'},{'Lick in bout'},{'On-time'},{'Off-time'}];
xlsSizeLimit=59999;
if size(OptimalTmp,1)>=xlsSizeLimit
    for v=1:floor(size(OptimalTmp,1)./xlsSizeLimit)
    xlswrite(sprintf('%s\\Switch%.f\\Cage%.fOptimal%.f.xls',trend_folder,sw,sw,v),[OptimalTmpHeaders;OptimalTmp(((v-1)*xlsSizeLimit+1):(v*xlsSizeLimit),:)],1,sprintf('A1:G%.f',(xlsSizeLimit+1)));
    end
    xlswrite(sprintf('%s\\Switch%.f\\Cage%.fOptimal%.f.xls',trend_folder,sw,sw,v+1),[OptimalTmpHeaders;OptimalTmp((v*xlsSizeLimit+1):size(OptimalTmp,1),:)],1,sprintf('A1:G%.f',size(OptimalTmp,1)-v*(xlsSizeLimit-1)-1));
else
    xlswrite(sprintf('%s\\Switch%.f\\Cage%.fOptimal.xls',trend_folder,sw,sw),[OptimalTmpHeaders;OptimalTmp]);
end
end

Filename={'Bouts per hour','Avg length of contacts','Avg Number of Licks per Microstructure','Microstructure Contact vs Non-Contact time (ms)',0,'Total Licks vs Contacts per hour',0,'Licks vs Contacts per bout'};
for id=1:nSw
switch_folder=sprintf('%s\\Switch%.f',trend_folder,id);
for u=2:4
    f1=figure(1);set(f1,'visible','off');
    i = days;
    bar(i, Trend(:,u,id));
    xlabel('Day');
    ylabel(Filename{u-1});
    saveas(f1,sprintf('%s\\Trend%.f %s.png',switch_folder,id,Filename{u-1}));
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
    saveas(f1,sprintf('%s\\Trend%.f %s.png',switch_folder,id,Filename{u-1}));
    close('all');
end
TrendData_file=sprintf('%s\\Trend%.f Data.xls',switch_folder,id);
TrendCells=[{'Day',Filename{1:3},'MicroStr contact time per lick','MicroStr non-contact time per lick','Tot licks','Tot contacts','Licks per bout','Contact per bout'};num2cell(Trend(:,:,id))];
xlswrite(TrendData_file,TrendCells, 'w');
end