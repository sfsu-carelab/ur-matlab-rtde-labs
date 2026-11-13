rmpath(userpath); global SIM SIM_ANSWER
lab = '/Users/ryancullen/GitHub Projects/ur-matlab-rtde-labs/labs/lab4-pick-and-place';
r = checkcode(fullfile(lab,'UR_PickPlace_Lab.m')); fprintf('checkcode messages: %d\n', numel(r)); for k=1:numel(r), fprintf('  L%d: %s\n', r(k).line, r(k).message); end
fprintf('\n===== RUN 1: NaN waypoints =====\n'); SIM_ANSWER='yes'; UR_PickPlace_NaN; assert(isempty(SIM.log),'moved with NaN waypoints');
fprintf('===== RUN 1b: waypoint check fails (Pre-Pick off to the side) =====\n'); SIM_ANSWER='yes'; UR_PickPlace_Bad; assert(isempty(SIM.log),'moved with a failed waypoint check');
fprintf('===== RUN 2: filled, answer "no" =====\n'); SIM_ANSWER='no'; UR_PickPlace_Filled; assert(isempty(SIM.log),'moved without yes');
fprintf('===== RUN 3: filled, answer "yes", slider 100%% =====\n'); SIM_ANSWER='yes'; UR_PickPlace_Filled; L=SIM.log; fprintf('%s\n', L{:});
assert(numel(L)==11 && strcmp(L{2},'gripper release') && strcmp(L{5},'gripper grip') && strcmp(L{9},'gripper release') && sum(startsWith(L,'move'))==8);
assert(max(abs(rad2deg(SIM.q) - [0 -80 -80 -110 90 0])) < 1e-6, 'did not end at home');
fprintf('===== RUN 4: slider 10%% (library wait returns false mid-move) =====\n'); 
copyfile('urRTDEClient.m','urRTDEClient_bak.txt'); t=fileread('urRTDEClient.m'); t=strrep(t,"'slider',1)","'slider',0.1)"); fid=fopen('urRTDEClient.m','w'); fwrite(fid,t); fclose(fid); rehash; clear urRTDEClient
UR_PickPlace_Filled; assert(numel(SIM.log)==11 && max(abs(rad2deg(SIM.q) - [0 -80 -80 -110 90 0])) < 1e-6);
fprintf('\nALL SIMULATED RUNS OK\n');
