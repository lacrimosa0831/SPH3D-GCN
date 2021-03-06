function s3dis_merge(voxelCloudDir)

classes = {'ceiling', 'floor', 'wall',  'beam', 'column', 'window',...
           'door','table', 'chair','sofa','bookcase', 'board','clutter'};

% compute evaluation metric by removing overlapping between blocks
baseDir = pwd;
baseDir(baseDir=='\') == '/';
str = split(pwd,'/');
sph3dgcnDir = join(str(1:end-1),'/');
sph3dgcnDir = sph3dgcnDir{:};
AreaID = 'Area_5';
matFolder = 'results_147';
debug_index = false;

disp(sph3dgcnDir);

total_intersect = zeros(numel(classes),1);
total_union = total_intersect;
total_seen = total_intersect;

merged_correct = 0;
merged_seen = 0;

Builds = dir(fullfile(voxelCloudDir, AreaID));
Builds = Builds(3:end);
dirFlags = [Builds.isdir];
Builds = Builds(dirFlags); % Extract only those that are directories
Builds = {Builds(:).name};
for i = 1:numel(Builds)
    load(fullfile(sph3dgcnDir,sprintf('data/s3dis_3cm/%s_%s.mat',AreaID,Builds{i})));
    
    gt_label = ptCloud(:,end);
    predictions = zeros(numel(gt_label),numel(classes));
    
    %% merge the predictions
    pred_files = dir(fullfile(sph3dgcnDir,sprintf('log_s3dis_%s',AreaID),matFolder,sprintf('%s_*.mat',Builds{i})));
    for k = 1:numel(pred_files)
        load(fullfile(pred_files(k).folder,pred_files(k).name));
        load(fullfile(strrep(pred_files(k).folder,matFolder,'block_index'),pred_files(k).name));
        
        in_index = data(:,11)==1;
        inner_pt = data(in_index,1:3);
        pred_logits = data(in_index,12:end);
        pred_logits = pred_logits./sqrt(sum(pred_logits.^2,2)); % normlize to unit vector
        pred_logits = exp(pred_logits)./sum(exp(pred_logits),2); % further normlize to probability/confidence
        
        block2full_index = index(in_index)+1;
        
        if debug_index
            [IDX, D] = knnsearch(inner_pt,ptCloud(:,1:3));
            figure(1);clf;plot3(ptCloud(D<0.03,1),ptCloud(D<0.03,2),ptCloud(D<0.03,3),'r.'),hold on
            plot3(ptCloud(block2full_index,1),ptCloud(block2full_index,2),ptCloud(block2full_index,3),'go'),hold on
        end
        
        predictions(block2full_index,:) = predictions(block2full_index,:) + pred_logits;
    end
        
    [~,pred_label] = max(predictions,[],2);
    pred_label = pred_label - 1; % pred_label in the voxelized point cloud
     
    voxelCloud = ptCloud;
    load(fullfile(sph3dgcnDir,sprintf('data/s3dis_full/%s_%s.mat',AreaID,Builds{i})));
    fullCloud = ptCloud;
    clear ptCloud;
    if debug_index %check if the point cloud are correctly aligned
        figure(1);clf;plot3(voxelCloud(:,1),voxelCloud(:,2),voxelCloud(:,3),'r.'),hold on
        plot3(fullCloud(:,1),fullCloud(:,2),fullCloud(:,3),'go'),hold on
    end
    
    % assign neighbor to the full point cloud based on the nearest neighbor
    % in the voxelized point cloud
    [IDX, D] = knnsearch(voxelCloud(:,1:3),fullCloud(:,1:3)); 
    gt_label = fullCloud(:,end);
    pred_label = pred_label(IDX); % pred_label in the original full point cloud
    for l = 1:numel(classes)
        total_intersect(l,1) = total_intersect(l,1) + sum((pred_label==(l-1)) & (gt_label==(l-1)));
        total_union(l,1)  = total_union(l,1) + sum((pred_label==(l-1)) | (gt_label==(l-1)));
        total_seen(l,1) = total_seen(l,1) + sum((gt_label==(l-1)));
    end
    merged_correct(1) = merged_correct(1) + sum(pred_label==gt_label);
    merged_seen(1) = merged_seen(1) + numel(pred_label);   
    
    fprintf('%.2f%%\n',100*merged_correct./(merged_seen+eps));
end

%% metric evaluation 
OA = merged_correct./(merged_seen+eps);
class_iou = total_intersect./(total_union+eps);
class_acc = total_intersect./(total_seen+eps);
fprintf('==================================class_OA==================================\n')
disp(OA(:)');
fprintf('=====================================end=====================================\n')
fprintf('==================================class_iou==================================\n')
disp(class_iou');
fprintf('=====================================end=====================================\n')
fprintf('==================================class_acc==================================\n')
disp(class_acc');
fprintf('=====================================end=====================================\n');
disp([mean(class_iou);mean(class_acc)]);

% save(fullfile(sph3dgcnDir, 's3dis_seg', sprintf('%s_metric',AreaID)),'merged_correct','merged_seen','total_intersect','total_union','total_seen'); 
