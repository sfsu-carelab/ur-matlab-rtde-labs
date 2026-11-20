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
        opts.View      (1,1) string {mustBeMember(opts.View, ["asis", "mirror", "rot180"])} = "asis"
                                              % transform of the primary frame before the policy (and in the figure)
    end

    %% ====================================================================
    %  SETTINGS
    %  ====================================================================
    robotIP   = "192.168.1.10";
    pyExe     = "C:\Users\924414657\vla-octo\win64\python\python.exe";
    vlapyDir  = "C:\Users\924414657\vla-octo\vlapy";
    % The script asks for the task when it starts, with no suggested text (Ryan, 2026-11-19).
    % The Task= option skips the prompt, which batch MATLAB needs (input() does not work there).
    if strlength(opts.Task) > 0
        task = opts.Task;
    else
        task = "";
        while strlength(task) == 0
            task = strtrim(string(input('\n  Task: ', 's')));
        end
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
    z_min  = 0.100;                               % MEASURED 2026-11-19 (flange Z over RTDE): OPEN fingertips 2 to 3 mm
                                                  % above the table at 84.9 mm; CLOSED fingertips resting on the table
                                                  % at 96.2 mm (the 2F-85 pads swing outward as the fingers close, so
                                                  % an empty close reaches 11 mm lower). Runs 4 and 5 at 0.085 and
                                                  % 0.095 dragged the closed tips. 0.105 (runs 6 to 9) held; in run 9
                                                  % the policy sat on the floor asking for lower for half the run, so
                                                  % Ryan lowered it to 0.100 (the Lab 4 grasp line, 4 mm above the
                                                  % empty-close touch point).
    z_max  = 0.53;                                % MEASURED 2026-11-19: Ryan jogged to the highest pose he wants
                                                  % allowed (nothing above the robot in reach); flange Z read 530.5 mm.

    % Samples drawn from the diffusion head per picture and averaged (octoChunk n_samples).
    % Run 9 (2026-11-19, Bridge-style camera) tracked the cube but jittered up to 19 mm
    % between steps and never committed a close; offline the head's spread was about equal
    % to its mean. 4 samples cost about 1 s per picture on this CPU.
    n_samples         = 4;
    action_scale      = 1.0;                      % multiply the translation delta
    max_step_m        = 0.02;                     % clamp per-step translation to this length
    % Map the policy's XY (WidowX base frame as seen by the Bridge camera) into our base
    % frame: [dX; dY] = action_xy_map * [dx; dy]. eye(2) = identity (runs 1 to 7).
    % A rotation is [c -s; s c]; a mirror is [1 0; 0 -1] (flip Y) or [-1 0; 0 1] (flip X).
    % Calibrate with two one-chunk runs: block image-right of the gripper (which sign of
    % dy?), block farther from the base (which sign of dx?); the run's saved frames show
    % where the block was. Run 7 (2026-11-19 16:35, white sheet): 9 cm in -Y, "away from
    % the block" (Ryan), so a mirror or a rotation is suspected, not yet measured.
    action_xy_map     = eye(2);
    apply_rotation    = false;                    % true: also apply the axis-angle rotation delta
    confirm_each_step = false;                    % true: Enter before every move. false (Ryan, after run 1,
                                                  % 2026-11-19): runs on its own; press q in the figure
                                                  % window to stop after the current step, or use the e-stop.
    primary_camera    = "435i RGB";               % webcamlist entry for the bird's-eye -> image_primary (256x256)
    % Crop of the 1280x720 frame [x0 y0 w h] in pixels, [] for none. In Bridge the gripper
    % and the objects fill the 256x256 input; in the full frame here the work area is the
    % middle third, so a block is about 10 pixels wide after the resize. 640x640 around the
    % start-pose gripper and the blocks (chosen on primary_now.png, 2026-11-19 16:30) makes
    % everything 2.5 times bigger. The figure shows the crop, i.e. what the policy sees.
    % The crop is tied to the camera position: when the camera moves, re-pick it on a fresh
    % frame. 2026-11-19 17:50: camera REMOUNTED Bridge-style (robot's right shoulder, about
    % 34 cm up, pitched down; notes section 18 to 20); crop chosen on primary_bridge2.png:
    % gripper top-left, block mid-frame, sheet to every edge.
    primary_crop      = [101 1 720 720];
    % Second camera behind the gripper, FPV (Ryan, 2026-11-19) -> Octo's image_wrist input
    % (128x128), which octo-base was pretrained with. use_wrist = false runs the bird's-eye
    % only (runs 1 and 2). The wrist unit needs a USB 3 cable: on USB 2 it enumerates, lists
    % four modes and never returns a frame (2026-11-04 and 2026-11-19 findings).
    use_wrist         = false;                    % default one camera until the 435if is on USB 3; Wrist=true for two
    wrist_camera      = "435if RGB";              % webcamlist entry for the wrist unit
    wrist_resolution  = "640x480";                % plenty for 128x128; in both the USB 2 and USB 3 mode lists
    if ~isempty(opts.Wrist), use_wrist = opts.Wrist; end
    fprintf('  Cameras: %s   View: %s\n', ternary(use_wrist, "bird's-eye + wrist", "bird's-eye only"), opts.View);

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
    % A fresh Python every run. The OutOfProcess interpreter otherwise lives on between runs
    % of this script and keeps the octoChunk module it first imported: after octoChunk.py
    % was edited on 2026-11-19 the desktop MATLAB kept calling the old step_chunk ("takes
    % from 2 to 3 positional arguments but 4 were given"), and py.importlib.reload did not
    % fix it. terminate(pyenv) is the MathWorks-documented way; it costs about a second.
    if pyenv().Status == "Loaded"
        terminate(pyenv);
    end
    pe = pyenv(Version=pyExe, ExecutionMode="OutOfProcess");
    fprintf('  Python %s (%s, fresh process)\n', pe.Version, pe.ExecutionMode);
    insert(py.sys.path, int64(0), vlapyDir);
    t = tic;
    mod = py.importlib.import_module("octoChunk");           % OctoInference + step_chunk (whole 4-step chunk)
    policy = py.octoChunk.OctoChunkInference();
    fprintf('  Octo loaded in %.1f s from %s\n', toc(t), char(py.getattr(mod, '__file__')));

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
    % dx,dy,dz are after the XY map and the clamp (what the robot was asked to do);
    % pol_dx,pol_dy,pol_dz are the policy's own output in metres, before either.
    fprintf(fid, 'chunk,step,t_policy_s,dx,dy,dz,rx,ry,rz,gripper,cur_x,cur_y,cur_z,tgt_x,tgt_y,tgt_z,executed,pol_dx,pol_dy,pol_dz,gripper_raw\n');
    frameBase = logFile(1:end-4);                             % frames saved as <log>_p01.png, _p01_wrist.png
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
        if ~isempty(primary_crop)
            r = primary_crop;
            img = img(r(2):r(2)+r(4)-1, r(1):r(1)+r(3)-1, :);
        end
        % View=mirror flips left-right (Ryan's test, 2026-11-19 17:25: is the sideways sign a
        % handedness problem?); View=rot180 turns the frame so the arm enters from the bottom
        % like a Bridge frame (section 18 of the notes). Offline neither changed the sideways
        % sign; this is the hardware check. The action map is NOT changed by View.
        switch opts.View
            case "mirror", img = fliplr(img);
            case "rot180", img = rot90(img, 2);
        end
        if ~opts.DryRun
            cur = readCartesianPose(ur);                     % [thetaz thetay thetax x y z], model FK
        end

        % ---- policy: the whole predicted chunk --------------------------
        t = tic;
        if use_wrist
            a = policy.step_chunk(py.numpy.array(img), task, pyargs('wrist_image', py.numpy.array(wimg), 'n_samples', int32(n_samples)));
        else
            a = policy.step_chunk(py.numpy.array(img), task, pyargs('n_samples', int32(n_samples)));
        end
        tp = toc(t);
        D = double(a{'world_vector'}) * action_scale;        % H x 3 translation deltas (m)
        R = double(a{'rot_axangle'});                        % H x 3 axis-angle deltas (rad)
        G = round(double(a{'gripper'}));  G = G(:)';         % 1 x H, +1 open / -1 close
        Graw = double(a{'gripper_raw'});  Graw = Graw(:)';   % 1 x H, 0 close ... 1 open (0.5 = threshold)
        n = min(chunk_steps, size(D, 1));
        D = D(1:n, :); R = R(1:n, :); G = G(1:n); Graw = Graw(1:n);
        Dpol = D;                                            % policy output, for the log

        % ---- map into the base frame and clamp every step ----------------
        for j = 1:n
            d = [(action_xy_map * D(j, 1:2)')', D(j, 3)];
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
        imwrite(img, sprintf('%s_p%02d.png', frameBase, k));         % what the policy saw (cropped)
        if use_wrist, imwrite(wimg, sprintf('%s_p%02d_wrist.png', frameBase, k)); end
        fprintf('  picture %2d  policy %.2f s\n', k, tp);
        for j = 1:n
            fprintf('     step %d  d = [%+6.1f %+6.1f %+6.1f] mm  rot = [%+.3f %+.3f %+.3f]  gripper %+d (%.2f)\n', ...
                j, 1000*D(j, :), R(j, :), G(j), Graw(j));
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
            fprintf(fid, '%d,%d,%.3f,%s,%d,%s,%s,%d,%s,%.3f\n', k, j, tp, csv([D(j, :) R(j, :)]), G(j), csv(prev(4:6)), csv(T(j, 4:6)), executed(j), csv(Dpol(j, :)), Graw(j));
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
