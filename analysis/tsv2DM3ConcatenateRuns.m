excludeSubjects;
load('project_params.mat')

% analyze blocks that were not identified as excluded blocks
which_blocks = toExclude==0;

unprocessed_dir = fullfile(fileparts(project_params.raw_dir), 'data');
load(fullfile(project_params.raw_dir,'subject_details.mat'));

N = size(toExclude,1);

% For RSA analysis, but with tasks by order in run rather than true task.

N = size(toExclude,1);

for i_s = which_subjects
    
    if sum(which_blocks(i_s,:))>1
        
        clear('names','onsets','durations','instruction_onsets','relevant_runs','runwise_offset','pmod');
        
        %% 1. initialize variables
        
        %     names of regressors.
        % C: counterclockwise
        % A: anticlockwise
        % Y: stimulus present
        % N: stimulus absent
        % T: tilted
        % V: vertical
        reg_names = {'A1','A2',...
            'B1','B2',...
            'C1','C2',...
            'ignore','index_finger_press',...
            'middle_finger_press','thumb_press', 'instructions'};
    
        % serial position of the first nuisance regressor
        first_nuis_idx = find(strcmp(reg_names,'ignore'));
        
        %create all regressors
        for i_r= 1:length(reg_names)
            names{i_r} = reg_names{i_r};
            onsets{i_r} = [];
            durations{i_r} = [];
        end
        
        %regressors of interest also get confidence modulators
        for i_r = 1:first_nuis_idx
            pmod(i_r).name{1} = 'confidence';
            pmod(i_r).param{1} = [];
            pmod(i_r).poly{1} = 1;
        end

        relevant_runs = find(which_blocks(i_s,:)>0);
        
        instruction_onsets = [];
        
        all_trial_onsets = [];
        
        for i_r = 1:numel(relevant_runs)
            
            events_file = fullfile(unprocessed_dir,['sub-',subj{i_s}.scanid],...
                'func',['sub-',subj{i_s}.scanid,'_task-unequalVariance_run-',...
                sprintf('%.2d',relevant_runs(i_r)),'_events.tsv']);
            
            %% 1. read table
            table = tdfread(events_file,'\t');
            
            runwise_offset = project_params.TR*179*(i_r-1);
            table.onset = table.onset+runwise_offset;
            
            
            %% 3. loop over events
            for event = 1:length(table.onset)
                
                % ignore trials that are marked as not included
                if strcmp(table.include(event,1),'0')
                    reg_idx = find(strcmp(reg_names,'ignore'));
                    onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                    durations{reg_idx} = [durations{reg_idx}; 4];
                
                    all_trial_onsets(end+1)=table.onset(event,:);
                    
                    % model trials that are included
                elseif any(strcmp({'A','C','Y','N','T','V'},...
                        table.trial_type(event,2)))
                    
                    task_number = mod(ceil(length(all_trial_onsets)/26),3);
                    task_letters = {'C','A','B'};
                    task_letter = task_letters{task_number+1};
                    resp = table.trial_type(event,2);
                    common_resp = ismember(resp, {'C','Y','T'})+1;
                    trial_type = sprintf('%s%d',task_letter,common_resp);

                    reg_idx = find(strcmp(reg_names,trial_type));
                    onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                    durations{reg_idx} = [durations{reg_idx}; 4];
                    pmod(reg_idx).param{1} = [pmod(reg_idx).param{1}; 
                        str2num(table.confidence(event,:))];
                
                    all_trial_onsets(end+1)=table.onset(event,:);

                % buttom presses have duration 0              
                elseif table.trial_type(event,:)=='button press'
                    if str2num(table.key_id(event,:))==50 %index finger
                        reg_idx = find(strcmp(reg_names,'index_finger_press'));
                        onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                        durations{reg_idx} = [durations{reg_idx}; 0];
                    elseif str2num(table.key_id(event,:))==51 %middle finger
                        reg_idx = find(strcmp(reg_names,'middle_finger_press'));
                        onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                        durations{reg_idx} = [durations{reg_idx}; 0];
                    elseif str2num(table.key_id(event,:))==54 % thumb
                        reg_idx = find(strcmp(reg_names,'thumb_press'));
                        onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                        durations{reg_idx} = [durations{reg_idx}; 0];
                    elseif str2num(table.key_id(event,:))==55 % thumb
                        reg_idx = find(strcmp(reg_names,'thumb_press'));
                        onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                        durations{reg_idx} = [durations{reg_idx}; 0];
                    end

                   
                    
                elseif strcmp(strtrim(table.trial_type(event,:)),'missed_trial')
                    if ~any(strcmp(names,'missed_trial'))
                        names{end+1} = 'missed_trial';
                        onsets{end+1} = [];
                        durations{end+1} = [];
                    end
                    reg_idx = find(strcmp(names,'missed_trial'));
                    onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                    durations{reg_idx} = [durations{reg_idx}; 4];
                    all_trial_onsets(end+1)=table.onset(event,:);
                    
                 elseif strcmp(strtrim(table.trial_type(event,:)),'instructions')
                    reg_idx = find(strcmp(names,'instructions'));
                    onsets{reg_idx} = [onsets{reg_idx}; table.onset(event,:)];
                    durations{reg_idx} = [durations{reg_idx}; 5];
                end
            end
            
        end
        
        all_trials_from_DM = [];
        for i = 1:first_nuis_idx
            all_trials_from_DM = [all_trials_from_DM; onsets{i}];
        end
        if strcmp(names{end},'missed_trial')
            all_trials_from_DM = [all_trials_from_DM; onsets{end}];
        end
        if ~all(sort(all_trials_from_DM)==all_trial_onsets')
                error('trials do not match')
        end
        
        %center confidence ratings
        for i=1:first_nuis_idx-1
            pmod(i).param{1} = pmod(i).param{1}-mean(pmod(i).param{1});
        end
        
        for i = 1:numel(pmod)
            switch numel(unique(pmod(i).param{1}))
                case 1
                    pmod(i).name{1} = [];
                    pmod(i).param{1} = [];
                    pmod(i).poly{1} = [];
                case 2
                    pmod(i).poly{1} = 1;
                otherwise
                    pmod(i).poly{1} = 2;
            end
        end
        
        for i_r = 1:6
            
            median_conf = median(pmod(i_r).param{1});
            
            %what portion of trials has equal or above median conf?
            p_geq = mean(pmod(i_r).param{1}>=median(pmod(i_r).param{1}));
            
            %what portion of trials has above median conf?
            p_g = mean(pmod(i_r).param{1}>median(pmod(i_r).param{1}));
            
            if abs(p_g-0.5)<abs(p_geq-0.5)
                
                %add epsilot to median_conf so that >= becomes >
                median_conf = median_conf+eps;
                
            end

            names{end+1} = [names{i_r},'_H'];
            onsets{end+1} = onsets{i_r}(pmod(i_r).param{1}>=median_conf);
            durations{end+1} = durations{i_r}(pmod(i_r).param{1}>=median_conf);
            
            names{i_r} = [names{i_r},'_L'];
            onsets{i_r} = onsets{i_r}(pmod(i_r).param{1}<median_conf);
            durations{i_r} = durations{i_r}(pmod(i_r).param{1}<median_conf);
            
            pmod(i_r).param = [];
            pmod(i_r).name = [];
            pmod(i_r).poly = [];
        
        end

        
        
        %%%%%%% REMOVE EMPTY ONSET FIELDS %%%%%%%%
        % note thas this step means that regressor numbers can differ between
        % subjects and runs. For example, names might be {'A', 'B'} for one run and
        % {'A','C','B'} for a different run. When running contrasts, make sure to
        % use the appropriate function, that uses beta names to generate contrast
        % vectors.
        empty_conditions = find(cellfun(@isempty,onsets));
        onsets(empty_conditions)=[];
        names(empty_conditions) = [];
        durations(empty_conditions)=[];
        pmod(empty_conditions) = [];
        
        subj{i_s}.scanid
        
        filename =  fullfile(project_params.data_dir, ['sub-',subj{i_s}.scanid], 'DM', ...
            'DM3_cr.mat');
        save(filename, 'names','onsets','pmod','durations');
    end
end
