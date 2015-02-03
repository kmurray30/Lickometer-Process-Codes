% Input file names to be processed
days = (1);%textread('C:\LickoMeterTemp\days.txt','%f','delimiter','\n','whitespace',''); %#ok<*DTXTRD>
out_files = {'Test2.txt'};%textread('C:\LickoMeterTemp\files.txt','%s','delimiter','\n','whitespace','');

destination= 'C:\LickoMeterTemp\'; %pwd is current folder
nSw=6; % Number of switches

Trend=zeros(length(days),10,nSw);
for sw=1:nSw
for d=1:length(days)
Trend_file_name=sprintf('%s\\LickoMeterTemp\\%s\\Switch%s\\Trend%s_Data',destination,out_files{d},sw,sw);
Trend(d,:,sw)=xlsread('C:\LickoMeterTemp\Trend5_Data',2);
end
end

%Create trend folder directories
trend_folder=sprintf('%s\\Trends',destination);
if exist(trend_folder,'dir')==7
rmdir(trend_folder,'s');
end
mkdir(trend_folder);
Filename={'Bouts per hour','Avg length of contacts','Avg Number of Licks per Microstructure','Microstructure Contact vs Non-Contact time (ms)',0,'Total Licks vs Contacts per hour',0,'Licks vs Contacts per bout'};
for id=1:nSw
switch_folder=sprintf('%s\\Switch%.f',trend_folder,id);
mkdir(switch_folder);
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