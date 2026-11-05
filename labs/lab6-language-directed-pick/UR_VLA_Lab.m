function UR_VLA_Lab()
%UR_VLA_LAB  Language-directed pick-and-place with a vision-language model.
%
%   You type an instruction such as "Put the red block on the blue square".
%   The robot takes a picture from the Lab 5 imaging pose, a vision-language
%   model (VLM) turns the picture plus your sentence into a pick point and a
%   place point, your Lab 5 calibration turns those pixels into base-frame
%   coordinates, the robot does the move, and then a second picture is sent
%   back to the model to ask whether the task worked. If it did not, the
%   script re-plans from the new picture and tries again (the "servoing"
%   loop).
%
%   Staged like Lab 5 - it runs as far as your entries allow, then stops:
%     Stage A (TASK 2):    imaging pose, capture, show
%     Stage B (TASK 3):    point at the target object with the VLM, compare
%                          with Lab 5 HSV detection if thresholds are set
%     Stage C (TASK 4):    plan pick + place from the instruction, convert to
%                          base XY, check they are inside the calibrated area
%     Stage D (TASK 5):    confirm, execute, verify, retry
%
%   Copy imaging_pose, UV/XY and ref_pick_pose straight from your Lab 5
%   script - the calibration is reused unchanged.
%
%   Required files (same folder or on the path): gemini_generate.m,
%   vlm_json.m, vlm_point.m, vlm_plan.m, vlm_verify.m,
%   xy_in_calibrated_area.m, and from Lab 5: capture_realsense.m,
%   detect_block.m, fit_pixel_to_base.m, pixel_to_base.m

    %% ====================================================================
    %  CONNECTION
    %  ====================================================================
    robotIP = "192.168.1.10";      % TODO: your robot's IP address
    % CobotName must match the arm: the default is universalUR5e, and readCartesianPose /
    % sendCartesianPoseAndWait use that model's kinematics (seen on hardware 2026-10-28).
    ur = urRTDEClient(robotIP, 'CobotName', 'universalUR3e');
    fprintf('\n  Connected to %s.\n', robotIP);

    %% ====================================================================
    %  TASK 2 - IMAGING POSE AND CALIBRATION (copy from Lab 5)
    %  ====================================================================
    imaging_pose = nan(1,6);       % TODO: Lab 5 Table 2, degrees
    UV = [ nan nan ; nan nan ; nan nan ; nan nan ];   % TODO: Lab 5 Table 4 pixels
    XY = [ nan nan ; nan nan ; nan nan ; nan nan ];   % TODO: Lab 5 Table 4 metres

    %% ====================================================================
    %  TASK 3 - WHAT TO POINT AT (plain English)
    %  ====================================================================
    target_object = "";            % TODO: e.g. "the red block"
    % Optional: your Lab 5 HSV thresholds for the same block, to compare the
    % two detectors side by side. Leave as NaN to skip the comparison.
    hsvLow  = [nan nan nan];
    hsvHigh = [nan nan nan];

    %% ====================================================================
    %  TASK 4 - THE INSTRUCTION
    %  ====================================================================
    instruction = "";              % TODO: e.g. "Put the red block on the blue square"

    %% ====================================================================
    %  TASK 5 - PICK REFERENCE POSE (copy from Lab 5) AND HEIGHTS
    %  ====================================================================
    ref_pick_pose = nan(1,6);      % TODO: [thetaz thetay thetax x y z] from Lab 5
    approach_dz   = 0.10;          % hover height above pick / place (m)
    place_dz      = 0.03;          % release this far above the pick height (m)
    bounds_margin = 0.03;          % how far outside the calibration box is allowed (m)
    maxAttempts   = 2;             % plan-execute-verify cycles before giving up
    moveEndTime   = 5;
    gripSettle    = 0.5;

    %% ====================================================================
    %  STAGE A - imaging pose and capture
    %  ====================================================================
    if any(isnan(imaging_pose))
        fprintf('  imaging_pose not set (TASK 2): copy it from Lab 5, then run again.\n'); return
    end
    fprintf('  Moving to the imaging pose...\n');
    moveToJ(ur, imaging_pose, moveEndTime);
    img = capture_realsense();
    figure(1); clf; imshow(img); title('Camera view from the imaging pose');

    %% ====================================================================
    %  STAGE B - point with words
    %  ====================================================================
    if strlength(target_object) == 0
        fprintf('  target_object not set (TASK 3): describe the block in words, then run again.\n'); return
    end
    t = tic;
    [uv, items] = vlm_point(img, target_object);
    fprintf('  VLM pointed in %.1f s.\n', toc(t));
    figure(2); clf; imshow(img); hold on;
    if isempty(uv)
        title(sprintf('VLM found no "%s"', target_object));
        fprintf('  The model returned no point for "%s". Reword it or check the view.\n', target_object);
        return
    end
    plot(uv(1,1), uv(1,2), 'yo', 'MarkerSize', 18, 'LineWidth', 2);
    text(uv(1,1)+12, uv(1,2), items(1).label, 'Color', 'y', 'FontSize', 12, 'FontWeight', 'bold');
    fprintf('  VLM: "%s" at pixel (%.1f, %.1f)\n', items(1).label, uv(1,:));
    if ~any(isnan([hsvLow hsvHigh]))
        uv_hsv = detect_block(img, hsvLow, hsvHigh, 200);
        if ~any(isnan(uv_hsv))
            plot(uv_hsv(1), uv_hsv(2), 'r+', 'MarkerSize', 18, 'LineWidth', 2);
            fprintf('  HSV: centroid at (%.1f, %.1f) - %.1f px apart (record in Table 2)\n', ...
                uv_hsv, norm(uv(1,:) - uv_hsv));
        else
            fprintf('  HSV: no blob with the given thresholds.\n');
        end
    end
    title(sprintf('VLM: %s (yellow)   HSV centroid (red +)', items(1).label));

    if any(isnan(UV(:))) || any(isnan(XY(:)))
        fprintf('  Calibration not entered (TASK 2): copy UV and XY from Lab 5, then run again.\n'); return
    end
    [A, ~, rms_mm] = fit_pixel_to_base(UV, XY);
    fprintf('  Calibration RMS %.2f mm. VLM point -> base (%.4f, %.4f) m\n', rms_mm, pixel_to_base(A, uv(1,:)));

    %% ====================================================================
    %  STAGE C - plan from the instruction
    %  ====================================================================
    if strlength(instruction) == 0
        fprintf('  instruction not set (TASK 4): write the sentence, then run again.\n'); return
    end
    [plan, pickXY, placeXY, okB] = planAndCheck(img, instruction, A, XY, bounds_margin, 3);
    if ~okB, return; end

    %% ====================================================================
    %  STAGE D - execute, verify, retry
    %  ====================================================================
    if any(isnan(ref_pick_pose))
        fprintf('  ref_pick_pose not set (TASK 5): copy it from Lab 5, then run again.\n'); return
    end

    before = img;
    for attempt = 1:maxAttempts
        fprintf('\n  ===== ATTEMPT %d of %d =====\n', attempt, maxAttempts);
        if attempt > 1
            % re-plan from the latest picture (the scene has changed)
            img = capture_realsense();
            [plan, pickXY, placeXY, okB] = planAndCheck(img, instruction, A, XY, bounds_margin, 3);
            if ~okB, return; end
        end

        fprintf('\n  WARNING: the robot will move to positions CHOSEN BY A LANGUAGE MODEL.\n');
        fprintf('  Pick  "%s" at (%.3f, %.3f) m\n', plan.pick_label,  pickXY);
        fprintf('  Place "%s" at (%.3f, %.3f) m\n', plan.place_label, placeXY);
        fprintf('  Speed slider 10%% for the first run. Clear the workspace. E-stop in hand.\n');
        if ~strcmpi(input('  Type "yes" to execute: ', 's'), 'yes')
            fprintf('  Aborted. Robot will not move.\n'); return
        end

        pick_pose  = ref_pick_pose;  pick_pose(4:5)  = pickXY;
        place_pose = ref_pick_pose;  place_pose(4:5) = placeXY;  place_pose(6) = place_pose(6) + place_dz;
        pre_pick   = pick_pose;      pre_pick(6)     = pick_pose(6)  + approach_dz;
        pre_place  = place_pose;     pre_place(6)    = pick_pose(6)  + approach_dz;

        t0 = tic;
        fprintf('  [1/8] Above the object...\n');    moveToC(ur, pre_pick,   moveEndTime);
        fprintf('  [2/8] Down to grasp...\n');       moveToC(ur, pick_pose,  moveEndTime);
        fprintf('  [3/8] Close gripper...\n');       grip(ur, 'grip', gripSettle);
        fprintf('  [4/8] Lift...\n');                moveToC(ur, pre_pick,   moveEndTime);
        fprintf('  [5/8] Over the destination...\n');moveToC(ur, pre_place,  moveEndTime);
        fprintf('  [6/8] Lower...\n');               moveToC(ur, place_pose, moveEndTime);
        fprintf('  [7/8] Release...\n');             grip(ur, 'release', gripSettle);
        fprintf('  [8/8] Back to the imaging pose...\n'); moveToC(ur, pre_place, moveEndTime);
        moveToJ(ur, imaging_pose, moveEndTime);
        fprintf('  Motion done in %.1f s.\n', toc(t0));

        % ---- verify with a second picture --------------------------------
        after = capture_realsense();
        figure(4); clf;
        subplot(1,2,1); imshow(before); title('Before');
        subplot(1,2,2); imshow(after);  title('After');
        [okV, why] = vlm_verify(before, after, instruction, ThinkingLevel="medium");
        fprintf('\n  VERIFY: %s\n  Model says: %s\n', ternary(okV, 'SUCCESS', 'NOT DONE'), why);
        if okV
            fprintf('\n  Task complete on attempt %d.\n\n', attempt);
            return
        end
        before = after;   % the next attempt is judged against this picture
    end
    fprintf('\n  Gave up after %d attempt(s). Record what the model said in Table 4.\n\n', maxAttempts);
end

% -------------------------------------------------------------------------
function [plan, pickXY, placeXY, ok] = planAndCheck(img, instruction, A, XY, margin, figNo)
    ok = false; pickXY = [NaN NaN]; placeXY = [NaN NaN];
    t = tic;
    plan = vlm_plan(img, instruction, ThinkingLevel="medium");
    fprintf('  VLM planned in %.1f s: pick "%s", place "%s"\n  Reason: %s\n', ...
        toc(t), plan.pick_label, plan.place_label, plan.reason);
    if any(isnan(plan.pick_uv)) || any(isnan(plan.place_uv))
        fprintf('  The model did not return both points. Reword the instruction.\n  Raw: %s\n', plan.text);
        return
    end
    figure(figNo); clf; imshow(img); hold on;
    plot(plan.pick_uv(1),  plan.pick_uv(2),  'go', 'MarkerSize', 18, 'LineWidth', 2);
    plot(plan.place_uv(1), plan.place_uv(2), 'ms', 'MarkerSize', 18, 'LineWidth', 2);
    text(plan.pick_uv(1)+12,  plan.pick_uv(2),  ['pick: '  plan.pick_label],  'Color', 'g', 'FontWeight', 'bold');
    text(plan.place_uv(1)+12, plan.place_uv(2), ['place: ' plan.place_label], 'Color', 'm', 'FontWeight', 'bold');
    title(instruction);

    pickXY  = pixel_to_base(A, plan.pick_uv);
    placeXY = pixel_to_base(A, plan.place_uv);
    [ok1, m1] = xy_in_calibrated_area(pickXY,  XY, margin);
    [ok2, m2] = xy_in_calibrated_area(placeXY, XY, margin);
    fprintf('  Pick : %s\n  Place: %s\n', m1, m2);
    ok = ok1 && ok2;
end

function moveToJ(ur, q_deg, endTime)
    q = deg2rad(q_deg);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    % 2026-11-04 hardware: the pendant speed slider scales the move but not the library's
    % wait (EndTime + 5 s), so at a low slider the call returns false while the robot is
    % still travelling, and a late "done" from one move can be read as the next move's
    % result. So we always confirm arrival ourselves before going on.
    ok = waitForArrival(ur, @() readJointConfiguration(ur), q, 1:6, deg2rad(0.5));
    if ~ok
        error('UR_VLA_Lab:moveFailed', 'Joint move to [%s] deg did not complete within 60 s.', join(string(q_deg), ', '));
    end
end

function moveToC(ur, pose, endTime)
    % 2026-11-04 hardware (Lab 5): the toolbox's Cartesian moves cut the path into 5 cm
    % pieces and run each as its own joint move, so the arm stops and starts along the way.
    % IK on the toolbox's own robot model plus one joint move gives one smooth motion.
    q0 = readJointConfiguration(ur);
    q  = poseToJoints(ur, pose, q0);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    ok = waitForArrival(ur, @() readCartesianPose(ur), pose, 4:6, 0.002);   % position within 2 mm
    if ~ok
        error('UR_VLA_Lab:moveFailed', 'Cartesian move to (%.3f, %.3f, %.3f) did not complete within 60 s.', pose(4:6));
    end
end

function q = poseToJoints(ur, pose, q0)
%POSETOJOINTS  Joint angles for pose on the toolbox's own model (ur.RigidBodyTree, the one
%   readCartesianPose uses; a plain loadrobot model is in a frame rotated 180 deg about Z).
%   Solved in 5 cm steps along the line from the current pose so the arm keeps its current
%   elbow and wrist configuration; only the final joint angles are returned, for one move.
    robot = ur.RigidBodyTree;
    ee    = robot.BodyNames{end};
    ik    = inverseKinematics(RigidBodyTree = robot);
    ik.SolverParameters.AllowRandomRestart = false;
    T0 = getTransform(robot, q0, ee);
    T1 = trvec2tform(pose(4:6)) * eul2tform(pose(1:3));            % toolbox pose convention
    n  = max(1, ceil(norm(tform2trvec(T1) - tform2trvec(T0)) / 0.05));
    q  = q0;
    for k = 1:n
        Tk = transformtraj(T0, T1, [0 1], k / n);
        [q, info] = ik(ee, Tk, [1 1 1 1 1 1], q);
    end
    if info.PoseErrorNorm > 1e-3
        error('UR_VLA_Lab:ikFailed', 'No joint solution near the current pose for (%.3f, %.3f, %.3f); pose error %.2g.', pose(4:6), info.PoseErrorNorm);
    end
end

function ok = waitForArrival(ur, readFcn, target, idx, tol)
%WAITFORARRIVAL  Poll readFcn until elements idx are within tol of target, no longer
%   changing between reads, AND the server script reports its last motion command
%   finished; then pause briefly so the server is ready for the next command. Gives up
%   after 60 s (a 5 s EndTime move at a 10 percent slider takes 50 s).
%
%   2026-11-04 hardware (Lab 5): the server script runs a Cartesian move as a chain of
%   movej segments and cannot read a new command until the last segment has returned.
%   At a 25 percent slider the next command was sent while the server was still inside
%   the last segment and was silently dropped. readMotionStatus reads the done flag.
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
%SERVERIDLE  True unless the server script is still executing a motion command.
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
%WAITFORGRIPPER  Wait for the server script to finish the gripper action.
%   2026-11-04 hardware (Lab 5): actuateGripper returns at once, but the server script
%   blocks inside the gripper call for about a second and drops any motion command sent
%   meanwhile. With URServerScript_Robotiq2F_PolyScopeX.script the gripper action is
%   reported through the same done flag as the moves, so wait for it to start, then to
%   finish. With a server script that does not report it, this is a plain 1.3 s wait.
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

function out = ternary(c, a, b)
    if c, out = a; else, out = b; end
end
