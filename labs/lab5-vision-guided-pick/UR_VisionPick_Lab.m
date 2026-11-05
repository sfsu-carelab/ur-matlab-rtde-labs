function UR_VisionPick_Lab()
%UR_VISIONPICK_LAB  Vision-guided pick-and-place with colored blocks.
%
%   The robot moves to a fixed IMAGING POSE, the wrist camera takes a
%   picture, the block is found by color, its pixel position is converted
%   to robot base coordinates with your calibration from Part 4, and the
%   robot picks it up and places it at your place waypoint.
%
%   The script is staged so you can run it repeatedly as you work through
%   the lab. It stops safely at whatever stage is not yet filled in:
%     Stage 1 (Part 2 done):  moves to the imaging pose, shows the camera
%                             image, then stops.
%     Stage 2 (Part 3 done):  also shows the detection overlay and the
%                             block centroid, then stops.
%     Stage 3 (Part 4 done):  also prints the predicted base X,Y, then stops.
%     Stage 4 (Part 5 done):  asks for confirmation, then runs the pick.
%
%   Works on any UR e-series cobot. Requires Labs 1-4 completed, the
%   camera mounted with payload updated (Lab 1, Section 3.2), and the
%   RealSense wrapper working (Part 1).
%
%   Required files (same folder): capture_realsense.m, detect_block.m,
%   fit_pixel_to_base.m, pixel_to_base.m
%
%   API reference:
%     https://www.mathworks.com/help/robotics/urseries/ref/urrtdeclient.html

    %% ====================================================================
    %  CONNECTION (as in Lab 2 / Lab 4)
    %  ====================================================================
    robotIP = "192.168.1.10";      % TODO: your robot's IP address
    % CobotName must match the arm: the default is universalUR5e, and readCartesianPose /
    % sendCartesianPoseAndWait use that model's kinematics (seen on hardware 2026-10-28).
    ur = urRTDEClient(robotIP, 'CobotName', 'universalUR3e');
    fprintf('\n  Connected to %s.\n', robotIP);

    %% ====================================================================
    %  TASK 2 - IMAGING POSE (joint angles, degrees)
    %  ====================================================================
    %  The camera is fixed above the table. Jog the robot to a parking pose
    %  that is completely out of the camera's view, then record the joint angles.
    imaging_pose = nan(1,6);       % TODO: [J1 J2 J3 J4 J5 J6] in degrees

    %% ====================================================================
    %  TASK 3 - COLOR THRESHOLDS (HSV, each channel 0..1)
    %  ====================================================================
    %  Tune these until the overlay shows one clean blob on your block.
    %  Red blocks need a wrap-around hue band, e.g. low h=0.95, high h=0.05.
    hsvLow    = [0.25 0.35 0.25];
    hsvHigh   = [0.45 1.00 1.00];
    minAreaPx = 200;

    %% ====================================================================
    %  TASK 4 - PIXEL-TO-BASE CALIBRATION (from Part 4, Table 4)
    %  ====================================================================
    %  One row per calibration placement: pixel centroid and the base-frame
    %  X,Y of the TCP touching the same spot. UR_CalibrateCamera walks you
    %  through the placements and prints these two lines ready to paste.
    UV = [ nan nan ;               % TODO: [u v] placement 1
           nan nan ;               % TODO: placement 2
           nan nan ;               % TODO: placement 3
           nan nan ];              % TODO: placement 4
    XY = [ nan nan ;               % TODO: [X Y] in METERS, placement 1
           nan nan ;               % TODO: placement 2
           nan nan ;               % TODO: placement 3
           nan nan ];              % TODO: placement 4

    %% ====================================================================
    %  TASK 5 - PICK REFERENCE AND PLACE WAYPOINT (from Part 5)
    %  ====================================================================
    %  ref_pick_pose: UR_CalibrateCamera prints it from your placement 1 touch
    %  (or touch down on a block ready to grasp and run readCartesianPose(ur)).
    %  It supplies the gripper orientation and the pick height; the script
    %  replaces only X and Y with the detected block position.
    ref_pick_pose = nan(1,6);      % TODO: [thetaz thetay thetax x y z] from readCartesianPose
    place_pos     = nan(1,6);      % TODO: [J1 J2 J3 J4 J5 J6] in degrees, drop-off waypoint

    approach_dz   = 0.10;          % approach height above the pick (m)
    moveEndTime   = 5;             % seconds scheduled per move (see Lab 4)
    gripSettle    = 0.5;

    %% ====================================================================
    %  STAGE 1 - move to the imaging pose and capture
    %  ====================================================================
    if any(isnan(imaging_pose))
        fprintf('  imaging_pose not set (TASK 2): fill it in, then run again.\n');
        return
    end
    fprintf('  Moving to the imaging pose...\n');
    moveToJ(ur, imaging_pose, moveEndTime);
    img = capture_realsense();
    figure(1); clf; imshow(img); title('Camera view from the imaging pose');

    %% ====================================================================
    %  STAGE 2 - detect the block
    %  ====================================================================
    [uv, mask] = detect_block(img, hsvLow, hsvHigh, minAreaPx);
    figure(2); clf;
    imshow(labeloverlay(img, mask)); hold on;
    if any(isnan(uv))
        title('No blob passed the threshold - tune TASK 3 and run again');
        fprintf('  No block detected: tune hsvLow/hsvHigh (TASK 3) and run again.\n');
        return
    end
    plot(uv(1), uv(2), 'r+', 'MarkerSize', 20, 'LineWidth', 2);
    title(sprintf('Detected centroid: u = %.1f, v = %.1f px', uv));
    fprintf('  Block detected at pixel (%.1f, %.1f).\n', uv);

    %% ====================================================================
    %  STAGE 3 - convert pixels to base coordinates
    %  ====================================================================
    if any(isnan(UV(:))) || any(isnan(XY(:)))
        fprintf('  Calibration table not complete (TASK 4): fill UV and XY, then run again.\n');
        return
    end
    [A, res_mm, rms_mm] = fit_pixel_to_base(UV, XY);
    fprintf('  Calibration residuals (mm): %s   RMS: %.2f mm  %s\n', ...
        join(string(round(res_mm,2)), ', '), rms_mm, pass_word(rms_mm));
    tgt = pixel_to_base(A, uv);
    fprintf('  Predicted block position: X = %.4f m, Y = %.4f m (base frame).\n', tgt);

    %% ====================================================================
    %  STAGE 4 - vision-guided pick
    %  ====================================================================
    if any(isnan(ref_pick_pose)) || any(isnan(place_pos))
        fprintf('  ref_pick_pose / place_pos not set (TASK 5): fill them in, then run again.\n');
        return
    end
    pick_pose = ref_pick_pose;  pick_pose(4:5) = tgt;      % swap in detected X,Y
    pre_pose  = pick_pose;      pre_pose(6)   = pre_pose(6) + approach_dz;

    fprintf('\n  WARNING: the robot will move to the DETECTED position.\n');
    fprintf('  Set the pendant speed slider to 10%% for the first run.\n');
    fprintf('  Clear the workspace and keep the e-stop within reach.\n\n');
    if ~strcmpi(input('  Type "yes" to run the vision-guided pick: ', 's'), 'yes')
        fprintf('  Aborted. Robot will not move.\n');
        return
    end

    t0 = tic;
    fprintf('  [1/7] Approach above the block...\n'); moveToC(ur, pre_pose,  moveEndTime);
    fprintf('  [2/7] Down to the pick pose...\n');    moveToC(ur, pick_pose, moveEndTime);
    fprintf('  [3/7] Closing gripper...\n');          grip(ur, 'grip', gripSettle);
    fprintf('  [4/7] Lifting...\n');                  moveToC(ur, pre_pose,  moveEndTime);
    fprintf('  [5/7] Moving to Place...\n');          moveToJ(ur, place_pos, moveEndTime);
    fprintf('  [6/7] Opening gripper...\n');          grip(ur, 'release', gripSettle);
    fprintf('  [7/7] Back to the imaging pose...\n'); moveToJ(ur, imaging_pose, moveEndTime);
    fprintf('\n  Vision-guided pick complete in %.1f s.\n\n', toc(t0));
end

% -------------------------------------------------------------------------
function moveToJ(ur, q_deg, endTime)
%MOVETOJ  Joint-space move (degrees in), blocking; see Lab 4.
    q = deg2rad(q_deg);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    % 2026-11-04 hardware: the pendant speed slider scales the move but not the library's
    % wait (EndTime + 5 s), so at a low slider the call returns false while the robot is
    % still travelling, and a late "done" from one move can be read as the next move's
    % result. So we always confirm arrival ourselves before going on.
    ok = waitForArrival(ur, @() readJointConfiguration(ur), q, 1:6, deg2rad(0.5));
    if ~ok
        error('UR_VisionPick_Lab:moveFailed', ...
            ['Joint move to [%s] deg did not complete. Check that the server ' ...
             'script node is running (green) and no protective stop is active.'], ...
            join(string(q_deg), ', '));
    end
end

% -------------------------------------------------------------------------
function moveToC(ur, pose, endTime)
%MOVETOC  Move the TCP to a Cartesian pose with ONE smooth joint move.
%   pose = [thetaz thetay thetax x y z] (rad, m), the convention of readCartesianPose.
    % 2026-11-04 hardware: the toolbox's Cartesian moves (sendCartesianPoseAndWait and
    % followCartesianWaypoints) cut the path into 5 cm pieces and run each piece as its own
    % joint move, so the arm visibly stops and starts along the way, and giving a blend
    % radius makes the library ignore the move time. Solving the pose to joint angles with
    % the same robot model the toolbox uses and sending one joint move gives one smooth,
    % time-parameterized motion. The path between the two points is joint-interpolated
    % rather than a straight line; over the 10 cm descent and lift the TCP bows sideways by
    % about 4 mm at mid-stroke and lands exactly on the target (checked offline 2026-11-04).
    q0 = readJointConfiguration(ur);
    q  = poseToJoints(ur, pose, q0);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    ok = waitForArrival(ur, @() readCartesianPose(ur), pose, 4:6, 0.002);   % position within 2 mm
    if ~ok
        error('UR_VisionPick_Lab:moveFailed', ...
            ['Cartesian move to x = %.3f, y = %.3f, z = %.3f did not complete. ' ...
             'If the target is outside the calibrated area or the reach of the ' ...
             'robot, recheck your calibration (TASK 4).'], pose(4), pose(5), pose(6));
    end
end

% -------------------------------------------------------------------------
function q = poseToJoints(ur, pose, q0)
%POSETOJOINTS  Joint angles that put the TCP at pose, found on the toolbox's own model.
%   Uses ur.RigidBodyTree, the model readCartesianPose is computed from (a plain
%   loadrobot('universalUR3e') sits in a frame rotated 180 degrees about Z and gives
%   X and Y with the wrong sign). The IK is solved in 5 cm steps along the straight
%   line from the current pose, each step seeded with the previous answer, so the
%   solution stays in the arm's current elbow and wrist configuration; only the final
%   joint angles are returned, for one move.
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
        error('UR_VisionPick_Lab:ikFailed', ...
            ['No joint solution near the current pose for x = %.3f, y = %.3f, z = %.3f ' ...
             '(pose error %.2g). Is the target within reach and inside the calibrated area?'], ...
            pose(4), pose(5), pose(6), info.PoseErrorNorm);
    end
end

% -------------------------------------------------------------------------
function ok = waitForArrival(ur, readFcn, target, idx, tol)
%WAITFORARRIVAL  Poll readFcn until elements idx are within tol of target, no longer
%   changing between reads, AND the server script reports its last motion command
%   finished; then pause briefly so the server is ready for the next command. Gives up
%   after 60 s (a 5 s EndTime move at a 10 percent slider takes 50 s).
%
%   2026-11-04 hardware: the server script runs a Cartesian move as a chain of movej
%   segments and cannot read a new command until the last segment has returned. Being
%   at the target is not enough: at a 25 percent slider the next command was sent while
%   the server was still inside the last segment and was silently dropped (the pick
%   descent, step 2/7, never started). readMotionStatus reads the server's done flag.
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

% -------------------------------------------------------------------------
function grip(ur, action, settleTime)
%GRIP  Robotiq gripper via the URCap; see Lab 4 for the digital-output note.
    actuateGripper(ur, action);
    waitForGripper(ur);
    pause(settleTime);
end

% -------------------------------------------------------------------------
function waitForGripper(ur)
%WAITFORGRIPPER  Wait for the server script to finish the gripper action.
%   2026-11-04 hardware: actuateGripper returns at once, but the server script blocks
%   inside the gripper call for about a second and drops any motion command sent
%   meanwhile (the lift after the first pick never started). With
%   URServerScript_Robotiq2F_PolyScopeX.script the gripper action is reported through
%   the same done flag as the moves, so wait for it to start, then to finish. With a
%   server script that does not report it, this is a plain 1.3 s wait.
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

% -------------------------------------------------------------------------
function w = pass_word(rms_mm)
    if rms_mm < 3,      w = '(excellent)';
    elseif rms_mm < 5,  w = '(acceptable)';
    else,               w = '(POOR - redo the worst calibration point)';
    end
end
