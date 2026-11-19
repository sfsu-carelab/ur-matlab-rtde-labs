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
%   delta (axis-angle, rad) and a gripper command (+1 open, -1 close). Octo actually
%   predicts 4 such steps per picture; since run 1 (2026-11-19) this script takes the whole
%   chunk (octoChunk.py, step_chunk) and runs it as ONE blended multi-waypoint move before
%   the next picture. MATLAB owns the camera, the robot and the loop:
%
%       capture -> policy.step_chunk -> clamp + bounds check on every waypoint
%               -> followJointWaypoints (blended) -> gripper -> repeat
%
%   The model was trained on the Bridge dataset (WidowX arm, over-the-shoulder camera).
%   Zero-shot on a UR3e with a bird's-eye D435i it is NOT expected to finish a task;
%   the point of this prototype is to measure what it does (direction of the first
%   steps, gripper timing, step time) before deciding on fine-tuning.
%
%   UR_VLA_Octo_Prototype                       % at the robot, from the MATLAB desktop; asks for the task
%   UR_VLA_Octo_Prototype(Wrist=true)           % same with the wrist camera as Octo's image_wrist
%   UR_VLA_Octo_Prototype(MaxSteps=15)          % same, longer run
%   UR_VLA_Octo_Prototype(DryRun=true)          % camera + policy only, no robot, no motion
%   UR_VLA_Octo_Prototype(DryRun=true, ImageFile="camera_1.png", Task="pick up the red block")
%                                               % fully offline; Task= skips the prompt (batch needs it)
%
%   SAFETY (same scaffolding as the labs): NaN placeholders stop the script until filled,
%   a typed "yes" before the first move, q in the figure window stops the loop (or Enter
%   before every step if confirm_each_step is true), a per-step translation clamp, a
%   keep-out box in base X, Y, Z, rotation deltas ignored unless apply_rotation is true,
%   every move waits for arrival. Speed slider at 100 percent or at least 50. E-stop in hand.
%
%   Needs: the USB Webcams support package (the camera is opened once and kept open).
%   Needs on disk:     the Octo Python environment from the 2026-11-19 session
%                      (C:\Users\924414657\vla-octo, see HANDOFF-NOTES.md in this folder).

    arguments
        opts.DryRun    (1,1) logical = false
        opts.ImageFile (1,1) string  = ""     % with DryRun: use this image instead of the camera
        opts.MaxSteps  (1,1) double  = 20
        opts.Task      (1,1) string  = ""     % skips the task prompt (needed in batch)
        opts.WristImageFile (1,1) string = "" % with DryRun + ImageFile and use_wrist: the wrist frame file
        opts.Wrist     logical {mustBeScalarOrEmpty} = []   % true/false overrides use_wrist for this run
    end

    %% ====================================================================
    %  SETTINGS
    %  ====================================================================
    robotIP   = "192.168.1.10";
    pyExe     = "C:\Users\924414657\vla-octo\win64\python\python.exe";
    vlapyDir  = "C:\Users\924414657\vla-octo\vlapy";
    task_default = "pick up the red block";       % offered at the prompt; Enter accepts it

    % The script asks for the task when it starts (Ryan, 2026-11-19). The Task= option
    % skips the prompt, which batch MATLAB needs because input() does not work there.
    if strlength(opts.Task) > 0
        task = opts.Task;
    else
        fprintf('\n  Tell the robot what to do, in one short sentence. Bridge-style wording\n');
        fprintf('  works best: "put the red block on the teal block", "pick up the red block".\n');
        typed = strtrim(string(input(sprintf('  Task [%s]: ', task_default), 's')));
        if strlength(typed) == 0, task = task_default; else, task = typed; end
    end
    fprintf('  Task: "%s"\n', task);

    % Start pose: gripper open, pointing straight down, 10 to 15 cm above the table, IN the
    % camera view together with the blocks (the policy must see its own gripper).
    % 2026-11-19 runs 1 and 2: [3.59 -101.4 -98.88 -69.58 89.36 180.9], flange (341.3, -110.9,
    % 224.8) mm. Run 2 closed the gripper 33 mm above the block, so run 3 starts 45 mm lower:
    % jogged by Ryan, read over RTDE, flange (356.3, -103.0, 179.4) mm, tool 0.6 deg from down.
    start_pose = [4.63 -109.08 -101.88 -59.64 89.74 184.59];   % joint angles in degrees

    % Keep-out box in base coordinates (metres). Use the Lab 6 calibration XY box plus margin
    % for X and Y; z_min = table touch height from the calibration + 0.005; z_max well below
    % anything the arm could hit. The script STOPS if a target leaves the box.
    % First-run box, 2026-11-19, from the Lab 4 flange poses measured 2026-11-16 (Pick at
    % X 452 Y -77 Z 100 mm, Place at X 309 Y -295 Z 106 mm, Ready Z 317 mm): the taped area
    % in front of the base, down to just above the Lab 4 grasp height, never above Ready.
    xy_min = [0.25 -0.35];                        % [X Y] min (m)
    xy_max = [0.50  0.00];                        % [X Y] max (m)
    z_min  = 0.105;                               % MEASURED 2026-11-19: open fingertips 2 to 3 mm above the table at
                                                  % flange Z 84.9 mm. Runs 4 and 5 (floors 0.085 and 0.095) both had
                                                  % the CLOSED fingertips hit the table: the 2F-85 pads swing outward
                                                  % as the fingers close, so an empty close reaches well below the
                                                  % open tips. 0.105 is 5 mm above the Lab 4 grasp line (100.4 mm,
                                                  % a cube between the pads). To measure instead of guess: close the
                                                  % gripper from the pendant, jog down until the pads touch, read Z.
    z_max  = 0.53;                                % MEASURED 2026-11-19: Ryan jogged to the highest pose he wants
                                                  % allowed (nothing above the robot in reach); flange Z read 530.5 mm.

    action_scale      = 1.0;                      % multiply the translation delta
    max_step_m        = 0.02;                     % clamp per-step translation to this length
    action_yaw_deg    = 0;                        % rotate the policy's XY frame into ours (Bridge: +x away from the robot, +y left)
    apply_rotation    = false;                    % true: also apply the axis-angle rotation delta
    confirm_each_step = false;                    % true: Enter before every move. false (Ryan, after run 1,
                                                  % 2026-11-19): runs on its own; press q in the figure
                                                  % window to stop after the current step, or use the e-stop.
    primary_camera    = "435i RGB";               % webcamlist entry for the bird's-eye -> image_primary (256x256)
    % Second camera behind the gripper, FPV (Ryan, 2026-11-19) -> Octo's image_wrist input
    % (128x128), which octo-base was pretrained with. use_wrist = false runs the bird's-eye
    % only (runs 1 and 2). The wrist unit needs a USB 3 cable: on USB 2 it enumerates, lists
    % four modes and never returns a frame (2026-11-04 and 2026-11-19 findings).
    use_wrist         = false;                    % default one camera until the 435if is on USB 3; Wrist=true for two
    wrist_camera      = "435if RGB";              % webcamlist entry for the wrist unit
    wrist_resolution  = "640x480";                % plenty for 128x128; in both the USB 2 and USB 3 mode lists
    if ~isempty(opts.Wrist), use_wrist = opts.Wrist; end
    fprintf('  Cameras: %s\n', ternary(use_wrist, "bird's-eye + wrist", "bird's-eye only"));

    % Chunk execution (Ryan, 2026-11-19, "option 2"): Octo predicts 4 steps per picture. The
    % first chunk_steps of them become cumulative targets, each solved to joint angles, and go
    % out as ONE followJointWaypoints call with a blend radius at the interior points, so the
    % arm rounds the corners instead of stopping at every step. Then a new picture is taken.
    % chunk_steps = 1 reproduces run 1 (one timed joint move per picture).
    chunk_steps       = 4;                        % how many of the 4 predicted steps to execute (1 to 4)
    chunk_step_time   = 0.6;                      % s per waypoint (WaypointTimes)
    chunk_velocity    = 0.3;                      % rad/s joint velocity cap for the blended move
    chunk_accel       = 0.5;                      % rad/s^2
    blend_radius      = 0.01;                     % m at interior waypoints (capped below to 40 percent of the shortest segment)
    moveEndTime       = 1.5;                      % s for a single-waypoint move at a 100 percent slider
    gripSettle        = 0.5;

    here = fileparts(mfilename('fullpath'));

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
    py.importlib.import_module("octoChunk");                 % OctoInference + step_chunk (whole 4-step chunk)
    policy = py.octoChunk.OctoChunkInference();
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
        fprintf('\n  WARNING: the robot will move to positions CHOSEN BY A VLA POLICY, %d blended steps per picture.\n', chunk_steps);
        fprintf('  Task: "%s"   max %d pictures, %.0f mm per step, box X [%.3f %.3f] Y [%.3f %.3f] Z [%.3f %.3f]\n', ...
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
    fprintf(fid, 'chunk,step,t_policy_s,dx,dy,dz,rx,ry,rz,gripper,cur_x,cur_y,cur_z,tgt_x,tgt_y,tgt_z,executed\n');
    Ryaw = eul2rotm([deg2rad(action_yaw_deg) 0 0]);          % ZYX, yaw only
    cur = nan(1,6);
    stopAfterThis = false;
    % Camera stays open for the whole run: one snapshot per step (capture_realsense reopens
    % the camera and waits 30 frames every call, about 3 s; run 1 spent most of each step there).
    cam = []; camW = [];
    offlineImages = opts.DryRun && strlength(opts.ImageFile) > 0;
    if ~offlineImages
        cam = openCamera(primary_camera, "1280x720");
        if use_wrist, camW = openCamera(wrist_camera, wrist_resolution); end
    elseif use_wrist && strlength(opts.WristImageFile) == 0
        error('UR_VLA_Octo_Prototype:noWristFile', 'use_wrist is true: give WristImageFile= with ImageFile=, or set use_wrist = false.');
    end
    fig = figure(1); clf;
    setappdata(fig, 'key', '');
    set(fig, 'KeyPressFcn', @(~, e) setappdata(fig, 'key', e.Key));
    fprintf('  Running. Click the figure window and press q to stop after the current chunk.\n');
    for k = 1:opts.MaxSteps                                  % one picture and one chunk per iteration
        % ---- observe ----------------------------------------------------
        wimg = [];
        if offlineImages
            img = imread(opts.ImageFile);
            if use_wrist, wimg = imread(opts.WristImageFile); end
        else
            img = snapshot(cam);
            if use_wrist, wimg = snapshot(camW); end
        end
        if ~opts.DryRun
            cur = readCartesianPose(ur);                     % [thetaz thetay thetax x y z], model FK
        end

        % ---- policy: the whole predicted chunk --------------------------
        t = tic;
        if use_wrist
            a = policy.step_chunk(py.numpy.array(img), task, py.numpy.array(wimg));
        else
            a = policy.step_chunk(py.numpy.array(img), task);
        end
        tp = toc(t);
        D = double(a{'world_vector'}) * action_scale;        % H x 3 translation deltas (m)
        R = double(a{'rot_axangle'});                        % H x 3 axis-angle deltas (rad)
        G = round(double(a{'gripper'}));  G = G(:)';         % 1 x H, +1 open / -1 close
        n = min(chunk_steps, size(D, 1));
        D = D(1:n, :); R = R(1:n, :); G = G(1:n);

        % ---- map into the base frame and clamp every step ----------------
        for j = 1:n
            d = (Ryaw * D(j, :)')';
            if norm(d) > max_step_m, d = d * (max_step_m / norm(d)); end
            D(j, :) = d;
        end
        % cumulative targets: waypoint j = current pose + sum of the first j deltas
        T = repmat(cur, n, 1);
        T(:, 4:6) = cur(4:6) + cumsum(D, 1);
        if apply_rotation
            Rcur = eul2rotm(cur(1:3)); %#ok<UNRCH>  (apply_rotation is a settings flag)
            for j = 1:n
                if norm(R(j, :)) > 0, Rcur = axang2rotm([R(j, :) / norm(R(j, :)), norm(R(j, :))]) * Rcur; end
                T(j, 1:3) = rotm2eul(Rcur);
            end
        end

        shown = img;
        if use_wrist, shown = [img, imresize(wimg, [size(img, 1) NaN])]; end   % bird's-eye | wrist
        imshow(shown); title(sprintf('picture %d  chunk total = [%+.1f %+.1f %+.1f] mm  gripper %+d  (%.2f s)   [q stops]', ...
            k, 1000*sum(D, 1), G(end), tp)); drawnow;
        fprintf('  picture %2d  policy %.2f s\n', k, tp);
        for j = 1:n
            fprintf('     step %d  d = [%+6.1f %+6.1f %+6.1f] mm  rot = [%+.3f %+.3f %+.3f]  gripper %+d\n', ...
                j, 1000*D(j, :), R(j, :), G(j));
        end
        if strcmp(getappdata(fig, 'key'), 'q')
            fprintf('  Stopped by the user (q in the figure window).\n'); break
        end

        executed = zeros(1, n);
        if ~opts.DryRun
            % ---- bounds (never move to an unchecked point) ----------------------------
            % Z: a target below z_min or above z_max is clamped to it (the policy pressing
            % down onto the table is normal grasp behaviour; the floor holds it). The later
            % waypoints of the chunk are shifted by the same amount, so they keep their shape.
            for j = 1:n
                zc = min(max(T(j, 6), z_min), z_max);
                if zc ~= T(j, 6)
                    fprintf('  waypoint %d Z %.3f clamped to %.3f\n', j, T(j, 6), zc);
                    T(j:end, 6) = T(j:end, 6) + (zc - T(j, 6));
                end
            end
            % X, Y: run the chunk up to the last waypoint inside the box, then stop the loop.
            inBox = all(T(:, 4:5) >= xy_min, 2) & all(T(:, 4:5) <= xy_max, 2);
            nOK = find(~inBox, 1) - 1;
            if isempty(nOK), nOK = n; end
            if nOK < n
                fprintf('  Waypoint %d (%.3f, %.3f, %.3f) is OUTSIDE the keep-out box: executing %d of %d, then stopping.\n', ...
                    nOK + 1, T(nOK + 1, 4:6), nOK, n);
                stopAfterThis = true;
            end
            if confirm_each_step && nOK > 0
                r = input('  Enter to execute this chunk, q to quit: ', 's'); %#ok<UNRCH>  (settings flag)
                if strcmpi(strtrim(r), 'q'), fprintf('  Stopped by the user.\n'); break; end
            end
            % ---- act: blended waypoints, split where the gripper command changes ---------
            j0 = 1;
            while j0 <= nOK
                jg = find(G(j0:nOK) ~= gripper_state, 1);    % first waypoint with a new gripper command
                if isempty(jg), j1 = nOK; else, j1 = j0 + jg - 1; end
                moveThrough(ur, T(j0:j1, :), chunk_step_time, chunk_velocity, chunk_accel, blend_radius, moveEndTime);
                if ~isempty(jg)
                    if G(j1) < 0, grip(ur, 'grip', gripSettle); else, grip(ur, 'release', gripSettle); end
                    gripper_state = G(j1);
                end
                j0 = j1 + 1;
            end
            executed(1:nOK) = 1;
        end
        prev = cur;
        for j = 1:n
            fprintf(fid, '%d,%d,%.3f,%s,%d,%s,%s,%d\n', k, j, tp, csv([D(j, :) R(j, :)]), G(j), csv(prev(4:6)), csv(T(j, 4:6)), executed(j));
            prev = T(j, :);
        end
        if stopAfterThis, break; end
    end
    fclose(fid);
    clear cam camW                                             % release the cameras
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

function out = ternary(c, a, b)
    if c, out = a; else, out = b; end
end

function cam = openCamera(pattern, resolution)
%OPENCAMERA  Open the RealSense RGB stream whose webcamlist name contains pattern, pin the
%   resolution, let auto-exposure settle (30 frames, see capture_realsense) and keep it open.
    if isempty(which('webcam'))
        error('UR_VLA_Octo_Prototype:noPackage', 'The USB Webcams support package is not on the path (Lab 5, Part 1).');
    end
    names = webcamlist;
    k = find(contains(names, pattern, 'IgnoreCase', true) & contains(names, 'RGB', 'IgnoreCase', true), 1);
    if isempty(k)
        error('UR_VLA_Octo_Prototype:noCamera', 'No camera matching "%s". webcamlist: %s', pattern, strjoin(names, ', '));
    end
    cam = webcam(names{k});
    if any(strcmp(cam.AvailableResolutions, resolution)), cam.Resolution = char(resolution); end
    fprintf('  Camera "%s" open at %s.\n', names{k}, cam.Resolution);
    for n = 1:30, snapshot(cam); end
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

function moveThrough(ur, T, stepTime, vel, acc, blend, singleEndTime)
%MOVETHROUGH  Run the rows of T (flange poses) as one blended joint-waypoint motion and
%   wait for arrival at the last one. One row: a single timed joint move, as in run 1.
    q0 = readJointConfiguration(ur);
    [Q, T, times, blend] = planWaypoints(ur, T, q0, stepTime, blend);
    if size(Q, 1) == 1
        sendJointConfigurationAndWait(ur, Q, EndTime = singleEndTime);
    else
        % 2026-11-19, from the toolbox source (manipulatorRTDEInterfaceInputParser,
        % sharedRTDEInterface.followJointWaypoints), found when the first chunk run errored:
        %  - the help text says one waypoint per ROW, but the parser counts waypoints as
        %    COLUMNS and the method transposes "6xN to Nx6", so the matrix goes in as 6 x N;
        %  - with a blend radius the waypoint times are zeroed (warning), so Velocity and
        %    Acceleration set the pace; times are only passed when blend is 0;
        %  - the FIRST and LAST waypoints always get blend 0, so the current joints are sent
        %    as waypoint 1 (a zero-length movej) and every chunk target can blend except the
        %    last, where the arm stops and the arrival check runs.
        Qsend = [q0; Q];
        if blend > 0
            followJointWaypoints(ur, Qsend', Velocity = vel, Acceleration = acc, BlendRadius = blend);
        else
            followJointWaypoints(ur, Qsend', WaypointTimes = [0 times], Velocity = vel, Acceleration = acc);
        end
    end
    ok = waitForArrival(ur, @() readCartesianPose(ur), T(end, :), 4:6, 0.002);
    if ~ok
        error('UR_VLA_Octo_Prototype:moveFailed', 'Move to (%.3f, %.3f, %.3f) did not complete within 60 s.', T(end, 4:6));
    end
end

function [Q, T, times, blend] = planWaypoints(ur, T, q0, stepTime, blend)
%PLANWAYPOINTS  Joint angles for each flange pose in T, chained from q0 so the arm keeps
%   its configuration. Waypoints closer than 2 mm to the previous one are merged (a
%   movej blend needs room), and the blend radius is capped at 40 percent of the shortest
%   remaining segment so no blend can exceed its segment. Pure function, no motion:
%   tested read-only against the live robot on 2026-11-19.
    p0 = tform2trvec(getTransform(ur.RigidBodyTree, q0, ur.RigidBodyTree.BodyNames{end}));
    keep = true(size(T, 1), 1);
    prev = p0;
    for j = 1:size(T, 1)
        if norm(T(j, 4:6) - prev) < 0.002 && j < size(T, 1), keep(j) = false; else, prev = T(j, 4:6); end
    end
    T = T(keep, :);
    nW = size(T, 1);
    Q = zeros(nW, 6);
    qprev = q0;
    for j = 1:nW
        Q(j, :) = poseToJoints(ur, T(j, :), qprev);
        qprev = Q(j, :);
    end
    times = stepTime * (1:nW);
    if nW > 1
        seg = vecnorm(diff([p0; T(:, 4:6)], 1, 1), 2, 2);
        blend = min(blend, 0.4 * min(seg));
    else
        blend = 0;
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
