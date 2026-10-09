function UR_PickPlace_Lab()
%UR_PICKPLACE_LAB  Pick-and-place on a UR e-series cobot over RTDE.
%
%   Commands the robot through the six-waypoint pick-and-place sequence you
%   recorded in Part 1, so you can compare it against the Teach Pendant
%   program you built in Part 2.
%
%   Works on any UR e-series cobot (UR3e, UR5e, UR7e, UR10e, UR12e, UR16e,
%   UR20, UR30) - the waypoints you enter below are what makes it specific
%   to your robot and workcell.
%
%   TASK 4 TIP: you can run this function BEFORE entering any waypoints -
%   it prints the connection readout and then stops safely, because the
%   waypoints below start out as NaN placeholders.
%
%   Prerequisites:
%     - Robotics System Toolbox
%     - Robotics System Toolbox Support Package for Universal Robots
%       UR Series Manipulators
%     - Robot powered on, URServerScript program loaded and playing (green
%       node in the program tree - see Lab 2), connected over Ethernet
%
%   API reference:
%     https://www.mathworks.com/help/robotics/urseries/ref/urrtdeclient.html

    %% ====================================================================
    %  TASK 4 - ESTABLISH THE RTDE CONNECTION
    %  ====================================================================
    %  TODO: enter the IP address of your robot (Lab 2, Part 4 set this to
    %  192.168.0.20; your instructor will confirm).
    % ---------------------------------------------------------------------

    robotIP = "192.168.0.20";        % TODO: your robot's IP address

    ur = urRTDEClient(robotIP);

    % --- Verify the connection by reading the current state ---
    % readJointConfiguration returns a 1x6 vector of joint angles in RADIANS.
    % readCartesianPose returns a 1x6 pose vector, NOT a 4x4 matrix:
    %     [thetaz, thetay, thetax, X, Y, Z]  in [rad rad rad m m m]
    % so the TCP position is elements 4:6.
    currentJoints = readJointConfiguration(ur);
    currentPose   = readCartesianPose(ur);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('  RTDE Connection Established\n');
    fprintf('============================================================\n');
    fprintf('  Robot IP: %s\n', robotIP);
    fprintf('  Joint angles (deg): [%.2f, %.2f, %.2f, %.2f, %.2f, %.2f]\n', ...
        rad2deg(currentJoints));
    fprintf('  TCP position  (m):  [%.4f, %.4f, %.4f]\n', currentPose(4:6));
    fprintf('============================================================\n\n');

    %% ====================================================================
    %  TASK 5 - ENTER YOUR WAYPOINTS
    %  ====================================================================
    %  TODO: enter the joint angles in DEGREES that you recorded in Part 1,
    %  Table 3.  Each is [J1 J2 J3 J4 J5 J6] exactly as the pendant shows.
    %
    %  The NaN placeholders are deliberate: the script refuses to move the
    %  robot until every waypoint is filled in. Do NOT enter zeros as
    %  placeholders - [0 0 0 0 0 0] is a real pose (arm fully outstretched).
    % ---------------------------------------------------------------------

    home_pos      = nan(1,6);   % TODO: safe start above the workspace
    pre_pick_pos  = nan(1,6);   % TODO: above the pick location
    pick_pos      = nan(1,6);   % TODO: down on the cube
    retract_pos   = nan(1,6);   % TODO: straight back up from Pick
    pre_place_pos = nan(1,6);   % TODO: above the place location
    place_pos     = nan(1,6);   % TODO: down at the place location

    % --- Motion timing ---
    %  IMPORTANT: when EndTime is non-zero, sendJointConfigurationAndWait
    %  time-parameterizes the move - the robot schedules EACH move to take
    %  about EndTime seconds, and any Velocity/Acceleration settings are
    %  ignored ("time takes precedence" per the MathWorks documentation).
    %  That makes motion slow, smooth and predictable, which is what we
    %  want in a teaching lab, but it also means the printed cycle time
    %  mostly reflects this setting rather than the path length - keep that
    %  in mind when you fill in Table 5 (and see Q3).
    %  Instructor option: EndTime = 0 uses the Velocity/Acceleration
    %  arguments instead, so moves run at their natural speed.
    moveEndTime       = 5;     % seconds scheduled per move
    gripperSettleTime = 0.5;   % seconds to wait after grip/release

    %% ====================================================================
    %  WAYPOINT CHECK - refuse to move until Task 5 is done
    %  ====================================================================

    wps = {home_pos, pre_pick_pos, pick_pos, retract_pos, pre_place_pos, place_pos};
    if any(cellfun(@(w) any(isnan(w)), wps))
        fprintf('  Waypoints are not entered yet (TASK 5), so the robot will not move.\n');
        fprintf('  Connection readout above is valid for Task 4 / Table 4.\n');
        fprintf('  Fill in all six waypoints, then run this script again.\n\n');
        return
    end

    %% ====================================================================
    %  SAFETY CHECK
    %  ====================================================================

    fprintf('  WARNING: the robot will move when you proceed.\n');
    fprintf('  Set the pendant speed slider to 10%% for the first run.\n');
    fprintf('  Clear the workspace and keep the e-stop within reach.\n\n');
    if ~strcmpi(input('  Type "yes" to run the sequence: ', 's'), 'yes')
        fprintf('  Aborted. Robot will not move.\n');
        return
    end
    fprintf('\n  Starting pick-and-place sequence...\n\n');

    %% ====================================================================
    %  MOTION SEQUENCE  (mirrors the Teach Pendant program from Part 2)
    %  ====================================================================

    steps = { ...
        'Moving to Home',          @() moveTo(ur, home_pos,      moveEndTime); ...
        'Moving to Pre-Pick',      @() moveTo(ur, pre_pick_pos,  moveEndTime); ...
        'Moving to Pick',          @() moveTo(ur, pick_pos,      moveEndTime); ...
        'Closing gripper',         @() grip(ur, 'grip',    gripperSettleTime); ...
        'Retracting',              @() moveTo(ur, retract_pos,   moveEndTime); ...
        'Moving to Pre-Place',     @() moveTo(ur, pre_place_pos, moveEndTime); ...
        'Moving to Place',         @() moveTo(ur, place_pos,     moveEndTime); ...
        'Opening gripper',         @() grip(ur, 'release', gripperSettleTime); ...
        'Retracting to Pre-Place', @() moveTo(ur, pre_place_pos, moveEndTime); ...
        'Returning to Home',       @() moveTo(ur, home_pos,      moveEndTime)};

    t0 = tic;
    for k = 1:size(steps, 1)
        fprintf('  [%2d/%d] %s...\n', k, size(steps,1), steps{k,1});
        steps{k,2}();
    end
    cycleTime = toc(t0);

    fprintf('\n  Sequence complete in %.1f s.\n', cycleTime);
    fprintf('  (Record this as the MATLAB RTDE cycle time in Table 5 - and note\n');
    fprintf('   that with time-parameterized moves it is roughly 8 x moveEndTime.)\n\n');

    %% ====================================================================
    %  FINAL STATE READOUT
    %  ====================================================================

    finalJoints = readJointConfiguration(ur);
    finalPose   = readCartesianPose(ur);

    fprintf('============================================================\n');
    fprintf('  Final State\n');
    fprintf('============================================================\n');
    fprintf('  Joint angles (deg): [%.2f, %.2f, %.2f, %.2f, %.2f, %.2f]\n', ...
        rad2deg(finalJoints));
    fprintf('  TCP position  (m):  [%.4f, %.4f, %.4f]\n', finalPose(4:6));
    fprintf('============================================================\n\n');
end

% -------------------------------------------------------------------------
function moveTo(ur, q_deg, endTime)
%MOVETO  Send one joint-space waypoint and block until the robot arrives.
%   Waypoints are entered in degrees; the RTDE API expects radians.
    ok = sendJointConfigurationAndWait(ur, deg2rad(q_deg), EndTime = endTime);
    if ~ok
        error('UR_PickPlace_Lab:moveFailed', ...
              ['Robot did not reach [%s] deg. Check that the server script ' ...
               'node is running (green) on the pendant, that the speed ' ...
               'slider is not near zero, and that no protective stop is ' ...
               'active. If the robot stopped mid-sequence while holding ' ...
               'the cube, release it from the pendant before re-running.'], ...
              join(string(q_deg), ', '));
    end
end

% -------------------------------------------------------------------------
function grip(ur, action, settleTime)
%GRIP  Open or close the gripper.
%
%   actuateGripper works with Robotiq grippers and requires the Robotiq
%   URCap to be installed on the robot and included in the robot program.
%   It is hardware-only - it does nothing against URSim.
%
%   If your gripper is driven from a digital output instead, note that
%   executeURScriptCommand HALTS the currently running robot program (the
%   URServerScript that RTDE motion depends on), so it cannot simply be
%   dropped in mid-sequence - you would have to press Play on the pendant
%   after each gripper action. Ask your instructor for the recommended
%   setup for your hardware; for reference, the command for digital
%   output 0 is:
%       executeURScriptCommand(ur, "set_digital_out(0, True)")
    actuateGripper(ur, action);
    pause(settleTime);
end
