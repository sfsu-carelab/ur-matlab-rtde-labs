function UR_VLA_Octo_Prototype(opts)
%UR_VLA_OCTO_PROTOTYPE  Closed-loop VLA on the UR3e with MATLAB in the loop (instructor prototype).
%
%   The Octo VLA (rail-berkeley/octo-base, 93M parameters, CPU) runs in a Python 3.10
%   process started by MATLAB (pyenv, OutOfProcess), through the SAME wrapper that
%   MathWorks ships in "Vision-Language-Action (VLA) Models in Simulink"
%   (github.com/mathworks/robot-vla-simulink, vlapy/octoModel.py). That example needs
%   R2025b and Simulink; this script makes the same two calls from plain R2024b:
%
%       model  = py.octoModel.OctoInference();
%       action = model.step(py.numpy.array(img), task);   % every control step
%
%   and gets back a 7-element action: end-effector translation delta (m), rotation
%   delta (axis-angle, rad) and a gripper command (+1 open, -1 close). MATLAB owns the
%   camera, the robot and the loop:
%
%       capture -> policy.step -> clamp + bounds check -> one joint move -> gripper -> repeat
%
%   The model was trained on the Bridge dataset (WidowX arm, over-the-shoulder camera).
%   Zero-shot on a UR3e with a bird's-eye D435i it is NOT expected to finish a task;
%   the point of this prototype is to measure what it does (direction of the first
%   steps, gripper timing, step time) before deciding on fine-tuning.
%
%   UR_VLA_Octo_Prototype                       % at the robot, from the MATLAB desktop
%   UR_VLA_Octo_Prototype(DryRun=true)          % camera + policy only, no robot, no motion
%   UR_VLA_Octo_Prototype(DryRun=true, ImageFile="camera_1.png")   % fully offline (batch OK)
%
%   SAFETY (same scaffolding as the labs): NaN placeholders stop the script until filled,
%   a typed "yes" before the first move, Enter before EVERY step while confirm_each_step
%   is true, a per-step translation clamp, a keep-out box in base X, Y, Z, rotation
%   deltas ignored unless apply_rotation is true, every move waits for arrival.
%   Speed slider at 100 percent or at least 50. E-stop in hand.
%
%   Needs on the path: capture_realsense.m (Lab 6 folder; added below).
%   Needs on disk:     the Octo Python environment from the 2026-11-19 session
%                      (C:\Users\924414657\vla-octo, see HANDOFF-NOTES.md in this folder).

    arguments
        opts.DryRun    (1,1) logical = false
        opts.ImageFile (1,1) string  = ""     % with DryRun: use this image instead of the camera
        opts.MaxSteps  (1,1) double  = 20
    end

    %% ====================================================================
    %  SETTINGS
    %  ====================================================================
    robotIP   = "192.168.1.10";
    pyExe     = "C:\Users\924414657\vla-octo\win64\python\python.exe";
    vlapyDir  = "C:\Users\924414657\vla-octo\vlapy";
    task      = "pick up the red block";          % Bridge-style wording works best ("put the X on the Y")

    % Start pose: gripper open, pointing straight down, 10 to 15 cm above the table, IN the
    % camera view together with the blocks (the policy must see its own gripper).
    start_pose = nan(1,6);                        % TODO: joint angles in degrees

    % Keep-out box in base coordinates (metres). Use the Lab 6 calibration XY box plus margin
    % for X and Y; z_min = table touch height from the calibration + 0.005; z_max well below
    % anything the arm could hit. The script STOPS if a target leaves the box.
    xy_min = [nan nan];                           % TODO: [X Y] min
    xy_max = [nan nan];                           % TODO: [X Y] max
    z_min  = nan;                                 % TODO
    z_max  = nan;                                 % TODO

    action_scale      = 1.0;                      % multiply the translation delta
    max_step_m        = 0.02;                     % clamp per-step translation to this length
    action_yaw_deg    = 0;                        % rotate the policy's XY frame into ours (Bridge: +x away from the robot, +y left)
    apply_rotation    = false;                    % true: also apply the axis-angle rotation delta
    confirm_each_step = true;                     % Enter before every move (q to quit)
    moveEndTime       = 1.5;                      % s per step at a 100 percent slider
    gripSettle        = 0.5;

    here = fileparts(mfilename('fullpath'));
    labDir = fullfile(here, '..', '..', '..', '..', 'labs', 'lab6-language-directed-pick');
    addpath(labDir);

    %% ====================================================================
    %  POLICY (Python co-execution, same calls as robotpolicy.m)
    %  ====================================================================
    if ~isfile(pyExe)
        error('UR_VLA_Octo_Prototype:noPython', 'Python not found at %s. See HANDOFF-NOTES.md.', pyExe);
    end
    pe = pyenv;
    if pe.Status == "Loaded" && ~strcmp(pe.Executable, pyExe)
        terminate(pyenv);
        pe = pyenv;
    end
    if pe.Status ~= "Loaded"
        pe = pyenv(Version=pyExe, ExecutionMode="OutOfProcess");
    end
    fprintf('  Python %s (%s)\n', pe.Version, pe.ExecutionMode);
    if count(py.sys.path, vlapyDir) == 0
        insert(py.sys.path, int64(0), vlapyDir);
    end
    t = tic;
    py.importlib.import_module("octoModel");
    policy = py.octoModel.OctoInference();
    fprintf('  Octo loaded in %.1f s.\n', toc(t));

    %% ====================================================================
    %  ROBOT
    %  ====================================================================
    ur = [];
    if ~opts.DryRun
        if any(isnan(start_pose)) || any(isnan([xy_min xy_max z_min z_max]))
            fprintf('  start_pose or the keep-out box is not set (SETTINGS): fill them in, then run again.\n'); return
        end
        ur = urRTDEClient(robotIP, 'CobotName', 'universalUR3e');
        fprintf('  Connected to %s.\n', robotIP);
        fprintf('\n  WARNING: the robot will move to positions CHOSEN BY A VLA POLICY, one step at a time.\n');
        fprintf('  Task: "%s"   max %d steps, %.0f mm per step, box X [%.3f %.3f] Y [%.3f %.3f] Z [%.3f %.3f]\n', ...
            task, opts.MaxSteps, 1000*max_step_m, xy_min(1), xy_max(1), xy_min(2), xy_max(2), z_min, z_max);
        fprintf('  Clear the workspace. Speed slider 100 percent. E-stop in hand.\n');
        if ~strcmpi(input('  Type "yes" to move to the start pose: ', 's'), 'yes')
            fprintf('  Aborted. Robot will not move.\n'); return
        end
        moveToJ(ur, start_pose, 5);
        grip(ur, 'release', gripSettle);
        gripper_state = +1;
    else
        gripper_state = +1;
        fprintf('  DRY RUN: no robot, actions are printed only.\n');
    end

    %% ====================================================================
    %  LOOP
    %  ====================================================================
    logFile = fullfile(here, sprintf('octo_run_%s.csv', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
    fid = fopen(logFile, 'w');
    fprintf(fid, 'step,t_policy_s,dx,dy,dz,rx,ry,rz,gripper,cur_x,cur_y,cur_z,tgt_x,tgt_y,tgt_z,executed\n');
    Ryaw = eul2rotm([deg2rad(action_yaw_deg) 0 0]);          % ZYX, yaw only
    cur = nan(1,6);
    figure(1); clf;
    for k = 1:opts.MaxSteps
        % ---- observe ----------------------------------------------------
        if opts.DryRun && strlength(opts.ImageFile) > 0
            img = imread(opts.ImageFile);
        else
            img = capture_realsense();
        end
        if ~opts.DryRun
            cur = readCartesianPose(ur);                     % [thetaz thetay thetax x y z], model FK
        end

        % ---- policy -----------------------------------------------------
        t = tic;
        action = policy.step(py.numpy.array(img), task);
        tp = toc(t);
        dxyz = double(action{2}{'world_vector'}) * action_scale;
        rax  = double(action{2}{'rot_axangle'});
        g    = round(double(action{2}{'gripper'}));          % +1 open, -1 close

        % ---- clamp and map into the base frame --------------------------
        dxyz = (Ryaw * dxyz(:))';
        n = norm(dxyz);
        if n > max_step_m, dxyz = dxyz * (max_step_m / n); end

        imshow(img); title(sprintf('step %d  d = [%+.1f %+.1f %+.1f] mm  gripper %+d  (%.2f s)', ...
            k, 1000*dxyz, g, tp)); drawnow;
        fprintf('  step %2d  policy %.2f s  d = [%+6.1f %+6.1f %+6.1f] mm  rot = [%+.3f %+.3f %+.3f]  gripper %+d\n', ...
            k, tp, 1000*dxyz, rax, g);

        tgt = cur;
        executed = 0;
        if ~opts.DryRun
            tgt(4:6) = cur(4:6) + dxyz;
            if apply_rotation && norm(rax) > 0
                Rcur = eul2rotm(cur(1:3)); %#ok<UNRCH>  (apply_rotation is a settings flag)
                tgt(1:3) = rotm2eul(axang2rotm([rax / norm(rax), norm(rax)]) * Rcur);
            end
            % ---- bounds (never move to an unchecked point) ----------------
            inBox = all(tgt(4:5) >= xy_min) && all(tgt(4:5) <= xy_max) && tgt(6) >= z_min && tgt(6) <= z_max;
            if ~inBox
                fprintf('  Target (%.3f, %.3f, %.3f) is OUTSIDE the keep-out box. Stopping.\n', tgt(4:6));
                fprintf(fid, '%d,%.3f,%s,%d,%s,%s,%d\n', k, tp, csv([dxyz rax]), g, csv(cur(4:6)), csv(tgt(4:6)), 0);
                break
            end
            if confirm_each_step
                r = input('  Enter to execute this step, q to quit: ', 's');
                if strcmpi(strtrim(r), 'q'), fprintf('  Stopped by the user.\n'); break; end
            end
            % ---- act ------------------------------------------------------
            moveToC(ur, tgt, moveEndTime);
            if g ~= gripper_state
                if g < 0, grip(ur, 'grip', gripSettle); else, grip(ur, 'release', gripSettle); end
                gripper_state = g;
            end
            executed = 1;
        end
        fprintf(fid, '%d,%.3f,%s,%d,%s,%s,%d\n', k, tp, csv([dxyz rax]), g, csv(cur(4:6)), csv(tgt(4:6)), executed);
    end
    fclose(fid);
    fprintf('\n  Log: %s\n', logFile);
    if ~opts.DryRun
        fprintf('  Returning to the start pose.\n');
        moveToJ(ur, start_pose, 5);
    end
end

% -------------------------------------------------------------------------
function s = csv(v)
    s = strjoin(compose('%.4f', v), ',');
end

% ---- motion helpers: copied from UR_VLA_Lab.m (2026-11-04 hardware findings) ------------
function moveToJ(ur, q_deg, endTime)
    q = deg2rad(q_deg);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    ok = waitForArrival(ur, @() readJointConfiguration(ur), q, 1:6, deg2rad(0.5));
    if ~ok
        error('UR_VLA_Octo_Prototype:moveFailed', 'Joint move to [%s] deg did not complete within 60 s.', join(string(q_deg), ', '));
    end
end

function moveToC(ur, pose, endTime)
    q0 = readJointConfiguration(ur);
    q  = poseToJoints(ur, pose, q0);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    ok = waitForArrival(ur, @() readCartesianPose(ur), pose, 4:6, 0.002);
    if ~ok
        error('UR_VLA_Octo_Prototype:moveFailed', 'Cartesian move to (%.3f, %.3f, %.3f) did not complete within 60 s.', pose(4:6));
    end
end

function q = poseToJoints(ur, pose, q0)
    robot = ur.RigidBodyTree;
    ee    = robot.BodyNames{end};
    ik    = inverseKinematics(RigidBodyTree = robot);
    ik.SolverParameters.AllowRandomRestart = false;
    T0 = getTransform(robot, q0, ee);
    T1 = trvec2tform(pose(4:6)) * eul2tform(pose(1:3));
    n  = max(1, ceil(norm(tform2trvec(T1) - tform2trvec(T0)) / 0.05));
    q  = q0;
    for k = 1:n
        Tk = transformtraj(T0, T1, [0 1], k / n);
        [q, info] = ik(ee, Tk, [1 1 1 1 1 1], q);
    end
    if info.PoseErrorNorm > 1e-3
        error('UR_VLA_Octo_Prototype:ikFailed', 'No joint solution near the current pose for (%.3f, %.3f, %.3f); pose error %.2g.', pose(4:6), info.PoseErrorNorm);
    end
end

function ok = waitForArrival(ur, readFcn, target, idx, tol)
    maxWait = 60;
    t0 = tic; prev = readFcn();
    while toc(t0) < maxWait
        pause(0.2);
        cur = readFcn();
        arrived = max(abs(cur(idx) - target(idx))) < tol && max(abs(cur(idx) - prev(idx))) < tol;
        if arrived && serverIdle(ur)
            pause(0.3);
            ok = true; return
        end
        prev = cur;
    end
    ok = false;
end

function idle = serverIdle(ur)
    try
        [~, state] = readMotionStatus(ur);
        idle = ~strcmpi(state, 'Executing');
    catch
        idle = false;
    end
end

function grip(ur, action, settleTime)
    actuateGripper(ur, action);
    waitForGripper(ur);
    pause(settleTime);
end

function waitForGripper(ur)
    t0 = tic; started = false;
    while toc(t0) < 1.0 && ~started
        pause(0.05); started = ~serverIdle(ur);
    end
    t0 = tic;
    while toc(t0) < 10 && ~serverIdle(ur)
        pause(0.05);
    end
    pause(0.3);
end
