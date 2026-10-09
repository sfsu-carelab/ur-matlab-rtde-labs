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
    robotIP = "192.168.0.20";      % TODO: your robot's IP address
    ur = urRTDEClient(robotIP);
    fprintf('\n  Connected to %s.\n', robotIP);

    %% ====================================================================
    %  TASK 2 - IMAGING POSE (joint angles, degrees)
    %  ====================================================================
    %  Jog the robot so the camera looks straight down at the workspace
    %  with every block position visible, then record the joint angles.
    imaging_pose = nan(1,6);       % TODO: [J1 J2 J3 J4 J5 J6] in degrees

    %% ====================================================================
    %  TASK 3 - COLOR THRESHOLDS (HSV, each channel 0..1)
    %  ====================================================================
    %  Tune these until the overlay shows one clean blob on your block.
    %  Red blocks need a wrap-around hue band, e.g. low h=0.95, high h=0.05.
    hsvLow    = [0.25 0.35 0.25]; % TODO: tune (defaults roughly green)
    hsvHigh   = [0.45 1.00 1.00]; % TODO: tune
    minAreaPx = 200;

    %% ====================================================================
    %  TASK 4 - PIXEL-TO-BASE CALIBRATION (from Part 4, Table 3)
    %  ====================================================================
    %  One row per calibration placement: pixel centroid and the base-frame
    %  X,Y you measured by touching the same spot with the TCP.
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
    %  ref_pick_pose: with the TCP touched down on a block ready to grasp,
    %  run readCartesianPose(ur) and paste the six numbers here. It supplies
    %  the gripper orientation and the pick height; the script replaces only
    %  X and Y with the detected block position.
    ref_pick_pose = nan(1,6);      % TODO: [thetaz thetay thetax x y z] rad/m
    place_pos     = nan(1,6);      % TODO: place waypoint, joint angles in degrees

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
    ok = sendJointConfigurationAndWait(ur, deg2rad(q_deg), EndTime = endTime);
    if ~ok
        error('UR_VisionPick_Lab:moveFailed', ...
            ['Joint move to [%s] deg did not complete. Check that the server ' ...
             'script node is running (green) and no protective stop is active.'], ...
            join(string(q_deg), ', '));
    end
end

% -------------------------------------------------------------------------
function moveToC(ur, pose, endTime)
%MOVETOC  Cartesian move: pose = [thetaz thetay thetax x y z] (rad, m).
    ok = sendCartesianPoseAndWait(ur, pose, EndTime = endTime);
    if ~ok
        error('UR_VisionPick_Lab:moveFailed', ...
            ['Cartesian move to x = %.3f, y = %.3f, z = %.3f did not complete. ' ...
             'If the target is outside the calibrated area or the reach of the ' ...
             'robot, recheck your calibration (TASK 4).'], pose(4), pose(5), pose(6));
    end
end

% -------------------------------------------------------------------------
function grip(ur, action, settleTime)
%GRIP  Robotiq gripper via the URCap; see Lab 4 for the digital-output note.
    actuateGripper(ur, action);
    pause(settleTime);
end

% -------------------------------------------------------------------------
function w = pass_word(rms_mm)
    if rms_mm < 3,      w = '(excellent)';
    elseif rms_mm < 5,  w = '(acceptable)';
    else,               w = '(POOR - redo the worst calibration point)';
    end
end
