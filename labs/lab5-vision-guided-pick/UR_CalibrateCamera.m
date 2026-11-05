function UR_CalibrateCamera()
%UR_CALIBRATECAMERA  Guided pixel-to-base calibration for Lab 5, Part 4.
%
%   Run this from the MATLAB desktop once the camera is mounted, the robot is
%   connected and the thresholds below find your block. It walks you through
%   four block placements. For each one it:
%     1. waits for you to put the block down with the arm OUT OF THE CAMERA
%        VIEW and press Enter, then takes a picture and finds the block;
%     2. waits for you to jog the open gripper onto the block (centred, at
%        grasp height, pointing straight down) and press Enter, then reads
%        the TCP pose over RTDE.
%   The script never moves the robot. At the end it fits the map, prints the
%   residuals and prints the UV, XY and ref_pick_pose lines ready to paste
%   into UR_VisionPick_Lab.m (TASK 4 and TASK 5) and into Table 3.
%
%   Tips (from the 2026-11-04 hardware run):
%     - Spread the four spots over the whole area you will pick from. Points
%       that sit in one half of the picture give a map that is 10 mm off in
%       the other half.
%     - Keep every spot within comfortable reach: a spot that needs the arm
%       almost straight is fine for calibration but not for picking.
%     - Make the placement 1 touch a real "ready to grasp" pose: it is reused
%       as ref_pick_pose, which sets the pick height and gripper orientation.
%
%   Prerequisites: the same as UR_VisionPick_Lab (support packages, server
%   script playing on the pendant, camera on USB 3).

    %% ====================================================================
    %  SETTINGS - copy these from UR_VisionPick_Lab.m (TASK 1 and TASK 3)
    %  ====================================================================
    robotIP   = "192.168.1.10";        % TODO: your robot's IP address
    hsvLow    = [0.25 0.35 0.25];      % TODO: same thresholds as TASK 3
    hsvHigh   = [0.45 1.00 1.00];
    minAreaPx = 200;
    nPlacements = 4;                   % the manual asks for four; more is fine

    %% ====================================================================
    %  CONNECT (read-only use of the robot)
    %  ====================================================================
    ur = urRTDEClient(robotIP, 'CobotName', 'universalUR3e');
    q = readJointConfiguration(ur);
    fprintf('\n  Connected to %s. Joints (deg): [%s]\n', robotIP, ...
        join(string(round(rad2deg(q), 1)), ', '));
    fprintf('  This script never moves the robot. You jog it from the pendant.\n\n');

    UV = nan(nPlacements, 2);
    XY = nan(nPlacements, 2);
    touchPose = nan(nPlacements, 6);

    %% ====================================================================
    %  ONE PLACEMENT AT A TIME
    %  ====================================================================
    k = 1;
    while k <= nPlacements
        fprintf('---------------------------------------------------------------\n');
        fprintf('  Placement %d of %d\n', k, nPlacements);
        fprintf('---------------------------------------------------------------\n');

        % --- 1. picture with the arm out of view ---
        input(sprintf(['  Put the block at spot %d, jog the arm OUT of the camera view,\n' ...
                       '  then press Enter to take the picture: '], k), 's');
        img = capture_realsense();
        [uv, mask] = detect_block(img, hsvLow, hsvHigh, minAreaPx);
        figure(1); clf; imshow(labeloverlay(img, mask)); hold on;
        if any(isnan(uv))
            title(sprintf('Placement %d: no blob passed the threshold', k));
            fprintf('  No block found. Check the thresholds (TASK 3), the lighting,\n');
            fprintf('  and that the arm is out of view. Press Enter to try this spot again.\n');
            input('', 's');
            continue
        end
        plot(uv(1), uv(2), 'r+', 'MarkerSize', 20, 'LineWidth', 2);
        title(sprintf('Placement %d: centroid u = %.1f, v = %.1f px', k, uv));
        fprintf('  Block found at pixel (%.1f, %.1f). Check the red cross is on YOUR block.\n', uv);
        again = input('  Press Enter to keep it, or type r to retake: ', 's');
        if strcmpi(strtrim(again), 'r')
            continue
        end

        % --- 2. touch with the TCP ---
        input(['  Now jog the OPEN gripper onto the block: centred, at grasp height,\n' ...
               '  pointing straight down. Do not move the block. Press Enter when it is there: '], 's');
        p = readCartesianPose(ur);
        fprintf('  TCP at X = %.4f m, Y = %.4f m, Z = %.4f m (base frame).\n\n', p(4), p(5), p(6));

        UV(k, :) = uv;
        XY(k, :) = p(4:5);
        touchPose(k, :) = p;
        k = k + 1;
    end

    %% ====================================================================
    %  FIT AND REPORT
    %  ====================================================================
    [~, res_mm, rms_mm] = fit_pixel_to_base(UV, XY);
    fprintf('===============================================================\n');
    fprintf('  Calibration result\n');
    fprintf('===============================================================\n');
    for k = 1:nPlacements
        fprintf('  placement %d: pixel (%7.1f, %7.1f)  ->  XY (%.4f, %.4f) m   residual %.2f mm\n', ...
            k, UV(k, 1), UV(k, 2), XY(k, 1), XY(k, 2), res_mm(k));
    end
    fprintf('  RMS %.2f mm  %s\n\n', rms_mm, pass_word(rms_mm));
    if rms_mm >= 5
        [~, worst] = max(res_mm);
        fprintf('  Placement %d has the largest residual. Usual causes: the block moved between\n', worst);
        fprintf('  the picture and the touch, the TCP was not centred, or the arm was in the picture.\n');
        fprintf('  Run the script again and redo that spot.\n\n');
    end

    % --- lines to paste into UR_VisionPick_Lab.m ---
    fprintf('  Paste these into UR_VisionPick_Lab.m (TASK 4 and TASK 5) and copy them to Table 3:\n\n');
    fprintf('    UV = [ ');
    for k = 1:nPlacements
        fprintf('%7.1f %7.1f', UV(k, 1), UV(k, 2));
        if k < nPlacements, fprintf(' ;   %% placement %d\n           ', k); else, fprintf(' ];  %% placement %d\n', k); end
    end
    fprintf('    XY = [ ');
    for k = 1:nPlacements
        fprintf('%8.4f %8.4f', XY(k, 1), XY(k, 2));
        if k < nPlacements, fprintf(' ;   %% placement %d\n           ', k); else, fprintf(' ];  %% placement %d\n', k); end
    end
    fprintf('    ref_pick_pose = [%.4f %.4f %.4f %.4f %.4f %.4f];   %% touch pose at placement 1\n\n', touchPose(1, :));

    % --- keep a copy next to this script for your report ---
    outFile = fullfile(fileparts(mfilename('fullpath')), 'calibration_results.txt');
    fid = fopen(outFile, 'w');
    fprintf(fid, 'UR_CalibrateCamera %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
    for k = 1:nPlacements
        fprintf(fid, 'placement %d: u=%.1f v=%.1f  X=%.4f Y=%.4f  touch pose [%s]  residual %.2f mm\n', ...
            k, UV(k, 1), UV(k, 2), XY(k, 1), XY(k, 2), join(string(round(touchPose(k, :), 4)), ' '), res_mm(k));
    end
    fprintf(fid, 'RMS %.2f mm\n', rms_mm);
    fclose(fid);
    fprintf('  Saved a copy to %s\n\n', outFile);
end

% -------------------------------------------------------------------------
function w = pass_word(rms_mm)
    if rms_mm < 3,      w = '(excellent)';
    elseif rms_mm < 5,  w = '(acceptable)';
    else,               w = '(POOR - redo the worst placement)';
    end
end
