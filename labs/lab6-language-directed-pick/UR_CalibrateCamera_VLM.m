function UR_CalibrateCamera_VLM()
%UR_CALIBRATECAMERA_VLM  Guided pixel-to-base calibration for Lab 6, using the VLM.
%
%   Run this from the MATLAB desktop once the camera is mounted, the robot is
%   connected and your API key works (test_vlm_offline Part 2). It walks you
%   through four block placements. For each one it:
%     1. waits for you to put the block down with the arm OUT OF THE CAMERA
%        VIEW and press Enter, then takes a picture and asks the vision-
%        language model to point at the block (you describe it in words,
%        see calib_object below);
%     2. waits for you to jog the open gripper onto the block (centred, at
%        grasp height, pointing straight down) and press Enter, then reads
%        the flange pose over RTDE.
%   The script never moves the robot. At the end it fits the map, prints the
%   residuals and prints the imaging_pose, UV, XY and ref_pick_pose lines
%   ready to paste into UR_VLA_Lab.m (TASK 2 and TASK 5).
%
%   Why calibrate at all? The model sees pixels. It does not know where the
%   camera is, how wide its lens is, or how high the table sits. The four
%   touches measure all of that in one go: an affine map from pixel to base
%   X,Y that is valid for objects on the table plane, seen by this camera in
%   this position. Move the camera and you redo this (five minutes).
%
%   Tips (from the 2026-11-04 and 2026-11-16 hardware runs):
%     - Spread the four spots over the whole area you will pick from. Points
%       that sit in one half of the picture give a map that is 10 mm off in
%       the other half.
%     - Keep every spot within comfortable reach: a spot that needs the arm
%       almost straight is fine for calibration but not for picking.
%     - Make the placement 1 touch a real "ready to grasp" pose: it is reused
%       as ref_pick_pose, which sets the pick height and gripper orientation.
%     - The joint angles read at the placement 1 picture (arm out of view)
%       are printed as imaging_pose.
%
%   INPUT   none (edit the SETTINGS block)
%   OUTPUT  printed lines to paste into UR_VLA_Lab.m; calibration_results.txt
%           next to this script
%   EXAMPLE UR_CalibrateCamera_VLM
%
%   Required files (same folder): capture_realsense.m, vlm_point.m,
%   gemini_generate.m, vlm_json.m, fit_pixel_to_base.m

    %% ====================================================================
    %  SETTINGS
    %  ====================================================================
    robotIP      = "192.168.1.10";     % TODO: your robot's IP address
    calib_object = "the red block";    % TODO: describe the calibration block in words
    nPlacements  = 4;                  % the manual asks for four; more is fine

    %% ====================================================================
    %  CONNECT (read-only use of the robot)
    %  ====================================================================
    % CobotName must match the arm: readCartesianPose uses that model's kinematics.
    ur = urRTDEClient(robotIP, 'CobotName', 'universalUR3e');
    q = readJointConfiguration(ur);
    fprintf('\n  Connected to %s. Joints (deg): [%s]\n', robotIP, ...
        join(string(round(rad2deg(q), 1)), ', '));
    fprintf('  This script never moves the robot. You jog it from the pendant.\n\n');

    UV = nan(nPlacements, 2);
    XY = nan(nPlacements, 2);
    touchPose    = nan(nPlacements, 6);
    imaging_pose = nan(1, 6);

    %% ====================================================================
    %  ONE PLACEMENT AT A TIME
    %  ====================================================================
    k = 1;
    while k <= nPlacements
        fprintf('---------------------------------------------------------------\n');
        fprintf('  Placement %d of %d\n', k, nPlacements);
        fprintf('---------------------------------------------------------------\n');

        % --- 1. picture with the arm out of view, VLM points at the block ---
        input(sprintf(['  Put the block at spot %d, jog the arm OUT of the camera view,\n' ...
                       '  then press Enter to take the picture: '], k), 's');
        q_img = readJointConfiguration(ur);
        img = capture_realsense();
        figure(1); clf; imshow(img); hold on;
        try
            t = tic;
            [uv, items] = vlm_point(img, calib_object);
            dt = toc(t);
        catch e
            title(sprintf('Placement %d: the model call failed', k));
            fprintf('  Model call failed: %s\n', e.message);
            fprintf('  Press Enter to try this spot again (wait a minute if it was HTTP 429).\n');
            input('', 's');
            continue
        end
        if isempty(uv)
            title(sprintf('Placement %d: the model found no "%s"', k, calib_object));
            fprintf('  The model returned no point for "%s" (%.1f s). Check the lighting,\n', calib_object, dt);
            fprintf('  that the arm is out of view, or reword calib_object. Press Enter to try again.\n');
            input('', 's');
            continue
        end
        uv = uv(1, :);
        plot(uv(1), uv(2), 'yo', 'MarkerSize', 18, 'LineWidth', 2);
        text(uv(1) + 12, uv(2), items(1).label, 'Color', 'y', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('Placement %d: VLM "%s" at u = %.1f, v = %.1f px', k, items(1).label, uv));
        fprintf('  The model pointed at "%s" at pixel (%.1f, %.1f) in %.1f s.\n', items(1).label, uv, dt);
        fprintf('  Check the yellow circle is on the CENTRE of YOUR block.\n');
        again = input('  Press Enter to keep it, or type r to retake: ', 's');
        if strcmpi(strtrim(again), 'r')
            continue
        end

        % --- 2. touch with the TCP ---
        input(['  Now jog the OPEN gripper onto the block: centred, at grasp height,\n' ...
               '  pointing straight down. Do not move the block. Press Enter when it is there: '], 's');
        p = readCartesianPose(ur);
        fprintf('  Flange at X = %.4f m, Y = %.4f m, Z = %.4f m (base frame, model).\n\n', p(4), p(5), p(6));

        UV(k, :) = uv;
        XY(k, :) = p(4:5);
        touchPose(k, :) = p;
        if k == 1
            imaging_pose = rad2deg(q_img);
        end
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
        fprintf('  the picture and the touch, the model pointed off-centre, the TCP was not\n');
        fprintf('  centred, or the arm was in the picture. Run the script again and redo that spot.\n\n');
    end

    % --- lines to paste into UR_VLA_Lab.m ---
    fprintf('  Paste these into UR_VLA_Lab.m (TASK 2 and TASK 5) and copy them to your tables:\n\n');
    fprintf('    imaging_pose = [%s];   %% joints (deg) at the placement 1 picture, arm out of view\n', ...
        join(string(round(imaging_pose, 2)), ' '));
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
    fprintf(fid, 'UR_CalibrateCamera_VLM %s   object "%s"\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), calib_object);
    fprintf(fid, 'imaging_pose (deg) [%s]\n', join(string(round(imaging_pose, 2)), ' '));
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
