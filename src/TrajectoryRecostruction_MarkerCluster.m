%% Markers trajectory recustruction
%------------------------------------------------------------------------------%

% Input file: file c3d 
% Output file: file c3d modified 

%------------------------------------------------------------------------------%

clear all
close all
clc


%% Info 
%------------------------------------------------------------------------------%

filename = 'proMMb1.c3d';

% Cluster marker IOR
cluster_right_thigh = {'RTH1';'RTH2';'RTH3'};
cluster_right_shank = {'RSH1';'RSH2';'RSH3'};
cluster_left_thigh  = {'LTH1';'LTH2';'LTH3'};
cluster_left_shank  = {'LSH1';'LSH2';'LSH3'};
cluster = {(cluster_right_thigh);(cluster_right_shank);(cluster_left_thigh);(cluster_left_shank)};
cluster_ref ={'RTH1';'RTH2';'RTH3';'RSH1';'RSH2';'RSH3';'LTH1';'LTH2';'LTH3';'LSH1';'LSH2';'LSH3'};

%% Load c3d & get the information 
%------------------------------------------------------------------------------%
% Acquisition file 
h = btkReadAcquisition(filename);
% Points & marker information 
[points, pointsInfo] = btkGetPoints(h);
markerName = fieldnames(points);

% Struct inizialize 
marker_ghost = struct(); % Markers that the cameras can't see 
marker_reference = struct(); % Marker used to reference 

% Auto-select the marker used to reference for every ghost marker
for i = 1:length(cluster_ref)
    for j = 1:length(markerName) 
        markerData = points.(markerName{j}); 
        if any(markerData == 0, 'all')
            marker_ghost.(markerName{j}) = markerData; 
        elseif contains(char(markerName(j)), char(cluster_ref(i)))
            marker_reference.(markerName{j}) = markerData;
        end
    end 
end 

%% Elaboration of the trajectory
%------------------------------------------------------------------------------%
% Loop to run all cluster 
% (cluster_right_thigh);(cluster_right_shank);(cluster_left_thigh);(cluster_left_shank)
for k = 1:length(cluster)
    % Input cluster 
    cluster_input = cluster{k};
    % Namer of marker ghost and marker refernce 
    structFieldNames_ghost = fieldnames(marker_ghost);
    structFieldNames_reference = fieldnames(marker_reference);

    % Loop to run marker ghost 
    for n = 1:length(structFieldNames_ghost)
        % Loop to run marker reference of cluster input 
        disp('========================')
        for m = 1:length(cluster_input)

            if ismember(structFieldNames_ghost{n},cluster_input(m)) % Control for every marker in the cluster if one or more of these is in the marker ghost structure 

                disp('-------------------')
                disp([char(cluster_input(m)) ' same from ' structFieldNames_ghost{n}])
                disp('-------------------')

                % Extract marker ghost value 
                values_ghost = marker_ghost.(structFieldNames_ghost{n});

                searchTerm = regexprep((structFieldNames_ghost{n}), '\d+', '');
                idx = find(contains((structFieldNames_reference), searchTerm));

                % Extract marker reference value
                values_reference = marker_reference.(structFieldNames_reference{idx});
                
                % Find zero points (marker not visible)
                zero_rows = all(values_ghost == 0, 2);
                % Index for the zero points 
                valid_points = ~zero_rows; % Trova dove i punti non sono nulli
                
                % Inizialize cells to save index start and end of zero interval
                intervals_start = {};
                intervals_end = {};
                % Find interval where valid_points = 0
                in_intervals = false;
                start_idx = 0; 
                for v = 1:length(valid_points)
                    if valid_points(v) == 0 && ~in_intervals
                        % Interval start
                        start_idx = v;
                        in_intervals = true;
                    elseif valid_points(v) == 1 && in_intervals
                        % Interval end
                        intervals_start{end+1}  = [start_idx];
                        intervals_end{end+1} = [v-1];
                        in_intervals = false;
                    end
                end 
                % Add at the last interval if it ended with 1
                if in_intervals
                    intervals_start{end+1} = [start_idx, length(valid_points)];
                end
                int_start = cell2mat(intervals_start);
                int_end = cell2mat(intervals_end);
               
                % Replace the values of the marker ghost with the vaues of
                % the marker refernce
                for c = 1:length(int_start)
                    offset =  values_ghost(int_end(c)+1,:)-values_reference(int_end(c)+1,:); % Offset between markers 
                    values_ghost1 = values_reference(int_start(c):int_end(c),:)+offset;
                    values_ghost(int_start(c):int_end(c),:) = values_ghost1;   
                end 
     
                % Set the results into Points and save the new acquisition 
                idx_final = find(contains(fieldnames(points), cluster_input(m)));
                [points, pointsInfo] = btkSetPoint(h, idx_final ,values_ghost);
            else 
                disp([char(cluster_input(m)) ' diffrente from ' structFieldNames_ghost{n}])
            end 
        end 
    end 
end

% Save the new file c3d
btkWriteAcquisition(h, 'filename_modified1.c3d');