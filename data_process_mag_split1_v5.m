% Input file names to be processed
days = textread('C:\LickoMeterTemp\days5.txt','%f','delimiter','\n','whitespace',''); %#ok<*DTXTRD>
out_files = textread('C:\LickoMeterTemp\files7.txt','%s','delimiter','\n','whitespace','');

% Define destination folder
destination= 'C:\LickoMeterTemp\'; %pwd is current folder
% Assign constants 
nSw=6; % Number of switches
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
end
end