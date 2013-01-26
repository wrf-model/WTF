function plotRegressionResults(resultsFile, releaseFile)
%function plotRegressionResults(resultsFile, releaseFile)
%
% Creates a checkerboard plot of regression pass/fails for a current
% version of WRF ('resultsFile') and the latest WRF release (releaseFile).


    % These are the types of tests that are run for each namelist. 
    testTypes = struct('build', {'serial',      'openmp',     'mpi',      'openmp',     'mpi'}, ...
                       'type',  {'FCST'  ,      'FCST'  ,     'FCST',     'BFB',        'BFB'}, ...
                       'labels', {'FCST_serial','FCST_openmp','FCST_mpi', 'BFB_openmp', 'BFB_mpi'});
    nTestTypes = length(testTypes);               


    if nargin < 2
        resultDirectory='/Volumes/sourgum2/bonnland/Regression_Testing/testRuns/RESULTS/';
        %resultsFile='~/Documents/MATLAB/RegressionTests/wrf_5922+.2012-08-27_15:13:43';
        %releaseFile='~/Documents/MATLAB/RegressionTests/testRelease.2012-08-27_15:27:53';
        %resultsFile='~/Documents/MATLAB/RegressionTests/wrf_5922+.2012-09-06_17:51:36';
        %resultsFile='~/Documents/MATLAB/RegressionTests/wrf_5962.2012-09-25_15:21:10';
        resultsFile = [resultDirectory 'wrf_5962.2012-10-11_01:47:46'];
        releaseFile = [resultDirectory 'WRFV3.4.2012-10-10_20:55:12'];
    end;

    
    % Data consists of six whitespace-separated strings per line:
    % <wrfType> <namelist> <parallelType> <testVariation> <testType> <result>
    
    fid = fopen(resultsFile,'r');
    data1=textscan(fid,'%s %s %s %s %s %s');
    fclose(fid);
    
    fid = fopen(releaseFile,'r');
    data2=textscan(fid,'%s %s %s %s %s %s');
    fclose(fid);
    
    % Collapse output from textscan() so we have a 2D cell array, instead
    % of a 1D collection of cell vectors.    The command says,
    % "Concatenate along dimension 2 (columns) the contents of the data (a
    % collection of column vectors).  
    data1=cat(2,data1{:});
    data2=cat(2,data2{:});
   
    close all
    
    
    wrfTypes=unique([data1(:,1); data2(:,1)]);
    
    % Build a 2D matrix of results for each WRF type  (X-axis for test variation, Y-axis for test namelist)
    for i=1:length(wrfTypes)
        wrfType=wrfTypes{i};
        % Isolate the rows in the data that match this WRF type.   
        cases1 = data1(strcmp(wrfType, data1(:,1)),:);
        cases2 = data2(strcmp(wrfType, data2(:,1)),:);
        namelists=unique([cases1(:,2); cases2(:,2)]);
        
        % Sort the namelist strings numerically, so 'namelist.input.2'
        % comes before 'namelist.input.11'.
        namelists = sort_nat(namelists);
        
        nNamelists=length(namelists);
        variations=unique([cases1(:,4); cases2(:,4)]);
        nVariations=length(variations);
        
        % Get the results for the first WRF version.
        results1 = getResults3D(cases1, namelists, variations, testTypes);
        results1 = makeResults2D(results1);
        % Get the results for the second WRF version.
        results2 = getResults3D(cases2, namelists, variations, testTypes);
        results2 = makeResults2D(results2);
        
        % Interleave the results in a final table. 
        assert(all(size(results1) == size(results2)));
        results = zeros(2*size(results1,1), size(results1,2));
        results(1:2:end-1) = results1;
        results(2:2:end) = results2;
        
        % Plot results using white, red and green colors
        figure(i); clf;
        
        set(gcf,'Position',[35+10*i 325-10*i 1007 728]);
        cmap = [1 1 1; 1 0 1; 1 0 0; 0 1 0];
        colormap(cmap);
        
        % results(1,1) is plotted in *upper* left corner
        imagesc(results);
        set(gca,'CLim',[0 3]);
        
        % Plot solid grid lines
        yLines = 0.5+[0:2:2*nNamelists];
        xLines = 0.5+[0:nTestTypes:nVariations*nTestTypes];
        gridxy(xLines,yLines,'LineStyle','-','LineWidth',1.5,'Color','k');
        
        % Plot minor grid lines
        xLines = [1.5:1.0:nTestTypes*nVariations-0.5];
        yLines = [1.5:1.0:2*nNamelists-0.5];
        gridxy(xLines,yLines,'LineStyle',':','LineWidth',1.5,'Color','k');
        
        % Y axis labels: One label for every pair of rows
        yTick = [1.5:2.0:2*nNamelists-0.5];
        set(gca, 'YTick',yTick, 'YTickLabel', namelists);
        
        % X axis labels: one for each value
        xTickLabels = repmat({testTypes.labels},1,nVariations);
        xTick = 1:nTestTypes*nVariations;
        assert(length(xTickLabels) == length(xTick));
        xticklabel_rotate(xTick,45,xTickLabels,'interpreter','none');
        
        % Title
        title1 = ['Regression Test Results for "' upper(wrfType) '"'];
        %title2 = [getBasename(resultsFile) '   vs.   ' getBasename(releaseFile)];
        title2 = '';
        title({title1; title2}, 'FontSize',16, 'FontWeight','bold', 'interpreter','none');
        
        % Variation names displayed along X axis
        variationX = [3:length(testTypes):nVariations*nTestTypes];
        variationY = 0.45 * ones(size(variationX));
        text(variationX,variationY,variations,'FontSize',12,'FontWeight','bold','FontAngle','italic',...
            'HorizontalAlignment','center','VerticalAlignment','bottom');
        
        % Results file names to the left of Y axis
        fileX = [0.6 0.6];
        fileY = [1 2];
        file1 = [getBasename(resultsFile) ' ---> '];
        file2 = [getBasename(releaseFile) ' ---> '];
        text(fileX,fileY,{file1 file2}, 'FontSize',9, ...
             'FontWeight','bold','FontAngle','italic', 'interpreter','none','Color','b');
                
        orient tall
        
        h=colorbar('YLim',[0 3],'YTick',[3 9 15 21]/8,'YTickLabel',{'Not Run','Compile Failed','Test Failed','Test Passed'});
        set(h,'Position',[0.847 0.838 0.018 0.086]);
        %export_fig(wrfType,'-nocrop','-zbuffer','-png');
        export_fig(wrfType,'-nocrop','-opengl','-pdf','-a1');
    end;  % Loop over WRF build types

end
    
    
    
    
% Return a set of results for a single WRF flavor (e.g. em_real)
%
function results = getResults3D(data, namelists, variations, testTypes)    
    % Build a boolean 2D array for storing results; initialize to NaN to
    % allow for "blank" spots in the plot.
    results = zeros(length(namelists), length(variations), length(testTypes));
    
    for j=1:length(namelists)
        name = namelists{j};
        for k=1:length(variations)
            var = variations{k};
            % Reduce to rows that match the namelist and variation.
            outcomes = data(strcmp(data(:,2), name) & strcmp(data(:,4), var), :);
            if ~isempty(outcomes)
                vector=getResultVector(outcomes, testTypes);
                results(j,k,:) = vector;
            end;
        end;   % Loop over variations
    end;  % Loop over namelists
end



function vect = getResultVector(outcomes, testTypes)

   vect = zeros(1,length(testTypes));

   for i=1:length(testTypes)
       inds = find(strcmp(testTypes(i).build, outcomes(:,3)) & strcmp(testTypes(i).type, outcomes(:,5)));
       assert(length(inds) <= 1);
       if ~isempty(inds)
           if strcmp(outcomes(inds,6),'PASS')
               vect(i) = 3;
           elseif strcmp(outcomes(inds,6),'FAIL')
               vect(i) = 2;
           elseif strcmp(outcomes(inds,6),'FAIL_COMPILE')
               vect(i) = 1;
           end;
       end;
   end;
end


% Reform the 3D results array into a 2D array, where elements from dimension 3 are placed
% in consecutive columns. 
function newResults = makeResults2D(results)
    [m,n,p] = size(results);
    newResults = zeros(m, n*p);
    for i = 1:m    % Loop over namelists
        for j=1:n     % Loop over variations
            rowIndexes = [p*(j-1)+1:p*j];
            newResults(i,rowIndexes) = results(i,j,:);
        end;
    end;
end



% Returns just the filename portion of a path (strip away parent
% directory names).
function baseName = getBasename(filePath, delim)
    if (nargin < 2)
        delim = '/';
    end;
    slashInds = strfind(filePath,delim);
    baseName = filePath(slashInds(end)+1:end);
end


