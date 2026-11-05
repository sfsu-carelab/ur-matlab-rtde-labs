function results = UR_HardwareSmokeTest(opts)
%UR_HARDWARESMOKETEST  Instructor pre-class check of every hardware call in Labs 2-6.
%
%   results = UR_HardwareSmokeTest()                       full run, asks before moving
%   results = UR_HardwareSmokeTest(DryRun=true)            connect, read, camera, API - no motion
%   results = UR_HardwareSmokeTest(Model="UR5e", TCPOffset=[0 0 0.160])
%
%   Exercises each RTDE / camera / GenAI primitive that the student scripts
%   rely on, in the order the labs use them, and writes a log you can hand
%   back for review:
%
%     test-logs/<timestamp>/smoketest.log      full console transcript (diary)
%     test-logs/<timestamp>/results.json       one PASS/FAIL/SKIP row per check
%     test-logs/<timestamp>/camera.png         the RealSense frame (if captured)
%
%   Sections
%     0  Environment    MATLAB release, toolboxes, UR support package, ping,
%                       RealSense wrapper, lab folders found
%     1  Lab 2  RTDE    urRTDEClient, readJointConfiguration, readCartesianPose
%     2  Lab 3  FK      screw-theory FK at the live joint angles vs the pose the
%                       robot reports (checks the sign convention on hardware)
%     3  Lab 2/4 Motion elbow +5 deg and back (sendJointConfigurationAndWait)
%     4  Lab 4  Gripper actuateGripper grip / release
%     5  Lab 5  Cart.   +2 cm straight up and back (sendCartesianPoseAndWait),
%                       confirms the [thetaz thetay thetax x y z] layout live
%     6  Lab 5  Camera  capture_realsense + detect_block on the frame
%     7  Lab 6  GenAI   API key, model list, one pointing call on the frame
%
%   Options (name=value)
%     RobotIP      "192.168.1.10"
%     Model        "UR3e"            any model in ur_link_lengths
%     TCPOffset    [0 0 0]           active TCP offset in the TOOL frame (m),
%                                    from the pendant TCP settings; needed for
%                                    section 2 to agree with the reported pose
%     DryRun       false             true = no motion and no gripper
%     SkipCamera   false
%     SkipGenAI    false
%     MoveEndTime  3                 seconds per test move
%     LogDir       ""                default <this folder>/test-logs
%     ConfirmMotion true             false skips the "type yes" prompt - only
%                                    for scripted repeat runs you are watching
%
%   Safety: sections 3-5 move the robot a few centimetres from wherever it
%   is. Start from a pose with clear space above and around the tool, speed
%   slider at 25 percent or less, e-stop in hand. The script asks once
%   before the first motion.

    arguments
        opts.RobotIP     (1,1) string  = "192.168.1.10"
        opts.Model       (1,1) string  = "UR3e"
        opts.TCPOffset   (1,3) double  = [0 0 0]
        opts.DryRun      (1,1) logical = false
        opts.SkipCamera  (1,1) logical = false
        opts.SkipGenAI   (1,1) logical = false
        opts.MoveEndTime (1,1) double  = 3
        opts.LogDir      (1,1) string  = ""
        opts.ConfirmMotion (1,1) logical = true
    end

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);                       % "MATLAB + RTDE" (Box layout)
    % GitHub layout: this file is instructor/hardware-validation/, so the repo root with
    % labs/ is two levels up (seen 2026-11-04 on PC 17: all three lab folders reported FAIL).
    if isempty(dir(fullfile(root, 'Lab 0*'))) && isfolder(fullfile(fileparts(root), 'labs'))
        root = fileparts(root);
    end

    % ---- log folder -----------------------------------------------------
    stamp = char(datetime('now', 'Format', 'yyyy-MM-dd_HHmmss'));
    if strlength(opts.LogDir) == 0
        logDir = fullfile(here, 'test-logs', stamp);
    else
        logDir = fullfile(char(opts.LogDir), stamp);
    end
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    diary(fullfile(logDir, 'smoketest.log'));
    cleanupDiary = onCleanup(@() diary('off'));

    R = struct('section', {}, 'name', {}, 'status', {}, 'detail', {});
    img = [];

    banner(sprintf('UR HARDWARE SMOKE TEST   %s', stamp));
    fprintf('  Options: IP=%s  Model=%s  TCPOffset=[%g %g %g]  DryRun=%d\n', ...
        opts.RobotIP, opts.Model, opts.TCPOffset, opts.DryRun);
    fprintf('  Log folder: %s\n\n', logDir);

    %% ===================================================================
    %  SECTION 0 - ENVIRONMENT
    %  ===================================================================
    banner('0  ENVIRONMENT');
    R(end+1) = row(0, 'MATLAB release', 'INFO', version);
    R(end+1) = row(0, 'Computer', 'INFO', sprintf('%s  (%s)', computer, getenv('COMPUTERNAME')));

    vv = ver;  names = {vv.Name};
    need = {'Robotics System Toolbox', 'Image Processing Toolbox'};
    for k = 1:numel(need)
        have = any(strcmp(names, need{k}));
        R(end+1) = row(0, need{k}, pf(have), ternary(have, 'installed', 'MISSING - install from Add-Ons')); %#ok<*AGROW>
    end

    spOK = false; spDetail = 'not found';
    try
        sp = matlabshared.supportpkg.getInstalled;
        if ~isempty(sp)
            hit = contains({sp.Name}, 'Universal Robots', 'IgnoreCase', true);
            if any(hit)
                spOK = true; spDetail = sp(find(hit,1)).Name;
            end
        end
    catch e
        spDetail = e.message;
    end
    R(end+1) = row(0, 'UR Series support package', pf(spOK), spDetail);
    R(end+1) = row(0, 'urRTDEClient on path', pf(~isempty(which('urRTDEClient'))), which('urRTDEClient'));

    % lab folders (Box layout "Lab 03 - ..." or GitHub layout labs/lab3-...)
    lab3 = findLab(root, {'Lab 03*', fullfile('labs','lab3*')});
    lab5 = findLab(root, {fullfile('Lab 05*','Code'), fullfile('labs','lab5*')});
    lab6 = findLab(root, {fullfile('Lab 06*','Code'), fullfile('labs','lab6*')});
    R(end+1) = row(0, 'Lab 3 folder', pf(~isempty(lab3)), lab3);
    R(end+1) = row(0, 'Lab 5 code folder', pf(~isempty(lab5)), lab5);
    R(end+1) = row(0, 'Lab 6 code folder', pf(~isempty(lab6)), lab6);
    for d = {lab3, lab5, lab6}
        if ~isempty(d{1}), addpath(d{1}); end
    end

    % ping
    if ispc, cmd = sprintf('ping -n 2 -w 1000 %s', opts.RobotIP);
    else,    cmd = sprintf('ping -c 2 -W 1 %s',    opts.RobotIP); end
    [st, out] = system(cmd);
    R(end+1) = row(0, sprintf('ping %s', opts.RobotIP), pf(st == 0), strtrim(lastLine(out)));

    % 2026-11-04: Lab 5 now captures through the USB Webcams support package, not the
    % RealSense SDK wrapper (lab PCs have no admin for the SDK installer).
    rsOK = ~isempty(which('webcam'));
    R(end+1) = row(0, 'USB Webcams support package', ternary(rsOK, 'PASS', 'WARN'), ...
        ternary(rsOK, which('webcam'), 'webcam not on path - install "MATLAB Support Package for USB Webcams" from Add-Ons (Lab 5 Part 1)'));

    printRows(R([R.section] == 0));

    %% ===================================================================
    %  SECTION 1 - LAB 2: CONNECT AND READ
    %  ===================================================================
    banner('1  LAB 2 - RTDE CONNECT / READ');
    ur = [];
    try
        % 2026-10-28 hardware: urRTDEClient defaults CobotName to universalUR5e and computes
        % readCartesianPose / Cartesian IK from that model, so the model must match the arm.
        t = tic; ur = urRTDEClient(opts.RobotIP, 'CobotName', char("universal" + opts.Model)); dt = toc(t);
        R(end+1) = row(1, 'urRTDEClient connect', 'PASS', sprintf('%.2f s', dt));
    catch e
        R(end+1) = row(1, 'urRTDEClient connect', 'FAIL', e.message);
        fprintf(2, '\n  Cannot connect - check the URServerScript node is PLAYING (green), RTDE enabled, IP correct.\n');
        finish(R, logDir); results = R; return
    end

    q0 = []; pose0 = [];
    try
        q0 = readJointConfiguration(ur);
        R(end+1) = row(1, 'readJointConfiguration', pf(numel(q0) == 6), ...
            sprintf('deg = [%s]', join(string(round(rad2deg(q0), 2)), ', ')));
    catch e
        R(end+1) = row(1, 'readJointConfiguration', 'FAIL', e.message);
    end
    try
        pose0 = readCartesianPose(ur);
        R(end+1) = row(1, 'readCartesianPose', pf(numel(pose0) == 6), ...
            sprintf('[%s]  (expect [thetaz thetay thetax x y z])', join(string(round(pose0, 4)), ', ')));
    catch e
        R(end+1) = row(1, 'readCartesianPose', 'FAIL', e.message);
    end
    printRows(R([R.section] == 1));

    %% ===================================================================
    %  SECTION 2 - LAB 3: FK vs REPORTED POSE
    %  ===================================================================
    banner('2  LAB 3 - SCREW-THEORY FK AT THE LIVE JOINT ANGLES');
    if isempty(q0) || isempty(pose0) || isempty(lab3)
        R(end+1) = row(2, 'FK vs reported pose', 'SKIP', 'needs joint read, pose read and Lab 3 folder');
    else
        try
            p = ur_link_lengths(opts.Model);
            [S, M] = urScrewModel(p);
            theta = hw2screw(rad2deg(q0(:)'));           % pendant deg -> PoE deg
            T = fk_space(S, M, theta);
            Rfk = T(1:3,1:3);  pFlange = T(1:3,4);
            pTCP = pFlange + Rfk * opts.TCPOffset(:);    % active TCP in model base frame
            pRep = pose0(4:6); pRep = pRep(:);
            errId  = norm(pTCP - pRep) * 1000;
            Rz180  = diag([-1 -1 1]);
            errYaw = norm(Rz180 * pTCP - pRep) * 1000;

            fprintf('  Joint angles (deg):      [%s]\n', join(string(round(rad2deg(q0),2)), ', '));
            fprintf('  FK flange position (m):  [%.4f %.4f %.4f]\n', pFlange);
            fprintf('  FK TCP position (m):     [%.4f %.4f %.4f]   (TCPOffset = [%g %g %g])\n', pTCP, opts.TCPOffset);
            fprintf('  Reported TCP (m):        [%.4f %.4f %.4f]\n', pRep);
            fprintf('  Position error: %.1f mm as-is, %.1f mm with 180 deg base yaw\n', errId, errYaw);
            fprintf('  Orientation, three conventions of the FK rotation for comparison\n');
            fprintf('    reported pose(1:3)            = [%.4f %.4f %.4f]\n', pose0(1:3));
            fprintf('    ZYX Euler [z y x] (rad)       = [%.4f %.4f %.4f]\n', rotm2eulZYX(Rfk));
            fprintf('    rotation vector (rad)         = [%.4f %.4f %.4f]\n', rotm2rotvec(Rfk));
            fprintf('    with 180 deg base yaw: Euler  = [%.4f %.4f %.4f]   rotvec = [%.4f %.4f %.4f]\n', ...
                rotm2eulZYX(Rz180*Rfk), rotm2rotvec(Rz180*Rfk));

            tolmm = 5;
            if errId < tolmm
                R(end+1) = row(2, 'FK position vs reported', 'PASS', sprintf('%.1f mm (same base frame)', errId));
            elseif errYaw < tolmm
                R(end+1) = row(2, 'FK position vs reported', 'WARN', ...
                    sprintf('%.1f mm only after a 180 deg base yaw - note this for the Lab 3 manual', errYaw));
            else
                R(end+1) = row(2, 'FK position vs reported', 'FAIL', ...
                    sprintf('%.1f mm. If this is close to |TCPOffset| of the gripper, rerun with TCPOffset set from the pendant.', min(errId, errYaw)));
            end
        catch e
            R(end+1) = row(2, 'FK vs reported pose', 'FAIL', e.message);
        end
    end
    printRows(R([R.section] == 2));

    %% ===================================================================
    %  MOTION GATE
    %  ===================================================================
    doMotion = ~opts.DryRun && ~isempty(q0);
    if doMotion
        fprintf('\n  The next three sections MOVE THE ROBOT (elbow +5 deg, gripper, +2 cm up).\n');
        fprintf('  Clear space around the tool, speed slider 25%% or less, e-stop in hand.\n');
        if opts.ConfirmMotion
            doMotion = strcmpi(input('  Type "yes" to allow motion (anything else skips): ', 's'), 'yes');
        end
    end

    %% ===================================================================
    %  SECTION 3 - LAB 2/4: JOINT MOVE
    %  ===================================================================
    banner('3  LAB 2 / LAB 4 - JOINT MOVE (elbow +5 deg and back)');
    if ~doMotion
        R(end+1) = row(3, 'sendJointConfigurationAndWait', 'SKIP', 'motion not enabled');
    else
        try
            target = q0; target(3) = target(3) + deg2rad(5);
            t = tic;
            % 2026-11-04: the library's wait ignores the pendant speed slider (see the labs'
            % waitForArrival); the library return is reported, the PASS is on actual arrival.
            ok1 = sendJointConfigurationAndWait(ur, target, EndTime = opts.MoveEndTime);
            arr1 = waitForArrival(ur, @() readJointConfiguration(ur), target, 1:6, deg2rad(0.5));
            qa  = readJointConfiguration(ur);
            ok2 = sendJointConfigurationAndWait(ur, q0, EndTime = opts.MoveEndTime);
            arr2 = waitForArrival(ur, @() readJointConfiguration(ur), q0, 1:6, deg2rad(0.5));
            qb  = readJointConfiguration(ur);
            dt  = toc(t);
            errA = max(abs(rad2deg(qa - target)));
            errB = max(abs(rad2deg(qb - q0)));
            R(end+1) = row(3, 'sendJointConfigurationAndWait', pf(arr1 && arr2), ...
                sprintf('library returned [%d %d], arrived [%d %d] (false library return = slider below ~50%%)', ok1, ok2, arr1, arr2));
            R(end+1) = row(3, 'arrival accuracy', pf(errA < 0.5 && errB < 0.5), ...
                sprintf('max joint error %.3f deg out, %.3f deg back', errA, errB));
            R(end+1) = row(3, 'timing of the two moves', 'INFO', ...
                sprintf('took %.1f s total with EndTime=%g (expect about %g s)', dt, opts.MoveEndTime, 2*opts.MoveEndTime));
        catch e
            R(end+1) = row(3, 'sendJointConfigurationAndWait', 'FAIL', e.message);
        end
    end
    printRows(R([R.section] == 3));

    %% ===================================================================
    %  SECTION 4 - LAB 4: GRIPPER
    %  ===================================================================
    banner('4  LAB 4 - GRIPPER (actuateGripper)');
    if ~doMotion
        R(end+1) = row(4, 'actuateGripper grip/release', 'SKIP', 'motion not enabled');
    else
        try
            t = tic;
            actuateGripper(ur, 'grip');    pause(1.0);
            actuateGripper(ur, 'release'); pause(1.0);
            R(end+1) = row(4, 'actuateGripper grip/release', 'PASS', ...
                sprintf('%.1f s round trip - CONFIRM BY EYE that the fingers closed and opened', toc(t)));
        catch e
            R(end+1) = row(4, 'actuateGripper grip/release', 'FAIL', ...
                [e.message '  (Robotiq URCap installed and in the program?)']);
        end
    end
    printRows(R([R.section] == 4));

    %% ===================================================================
    %  SECTION 5 - LAB 5: CARTESIAN MOVE
    %  ===================================================================
    banner('5  LAB 5 - CARTESIAN MOVE (+2 cm up in base Z and back)');
    if ~doMotion || isempty(pose0)
        R(end+1) = row(5, 'sendCartesianPoseAndWait', 'SKIP', 'motion not enabled');
    else
        try
            dz = 0.02;
            p1 = readCartesianPose(ur);          % fresh, after the joint moves
            up = p1; up(6) = up(6) + dz;
            ok1 = sendCartesianPoseAndWait(ur, up, EndTime = opts.MoveEndTime);
            arr1 = waitForArrival(ur, @() readCartesianPose(ur), up, 4:6, 0.002);
            pa  = readCartesianPose(ur);
            ok2 = sendCartesianPoseAndWait(ur, p1, EndTime = opts.MoveEndTime);
            arr2 = waitForArrival(ur, @() readCartesianPose(ur), p1, 4:6, 0.002);
            pb  = readCartesianPose(ur);

            dzMeas  = pa(6) - p1(6);
            dxyMeas = norm(pa(4:5) - p1(4:5)) * 1000;
            dRot    = max(abs(wrapToPiLocal(pa(1:3) - p1(1:3))));
            back    = norm(pb(4:6) - p1(4:6)) * 1000;
            fprintf('  Commanded +%.0f mm in element 6. Measured: dZ = %+.1f mm, dXY = %.1f mm, dRot = %.3f rad, return error %.1f mm\n', ...
                dz*1000, dzMeas*1000, dxyMeas, dRot, back);
            layoutOK = abs(dzMeas - dz) < 0.003 && dxyMeas < 3 && dRot < 0.02;
            R(end+1) = row(5, 'sendCartesianPoseAndWait', pf(arr1 && arr2), ...
                sprintf('library returned [%d %d], arrived [%d %d]', ok1, ok2, arr1, arr2));
            R(end+1) = row(5, 'pose layout [rot(3) xyz(3)], Z = element 6', pf(layoutOK), ...
                sprintf('dZ %+.1f mm (want +%.0f), dXY %.1f mm, dRot %.3f rad', dzMeas*1000, dz*1000, dxyMeas, dRot));
        catch e
            R(end+1) = row(5, 'sendCartesianPoseAndWait', 'FAIL', e.message);
        end
    end
    printRows(R([R.section] == 5));

    %% ===================================================================
    %  SECTION 6 - LAB 5: CAMERA
    %  ===================================================================
    banner('6  LAB 5 - CAMERA (capture_realsense + detect_block)');
    if opts.SkipCamera
        R(end+1) = row(6, 'capture_realsense', 'SKIP', 'SkipCamera');
    elseif isempty(lab5)
        R(end+1) = row(6, 'capture_realsense', 'SKIP', 'Lab 5 code folder not found');
    else
        try
            t = tic; img = capture_realsense(); dt = toc(t);
            imwrite(img, fullfile(logDir, 'camera.png'));
            R(end+1) = row(6, 'capture_realsense', pf(ndims(img) == 3 && size(img,3) == 3), ...
                sprintf('%dx%dx%d uint8 in %.1f s -> camera.png', size(img,1), size(img,2), size(img,3), dt));
            figure('Name', 'Smoke test - camera'); imshow(img); title('capture\_realsense');
            try
                [uv, mask] = detect_block(img, [0.25 0.35 0.25], [0.45 1.00 1.00], 200);
                if any(isnan(uv))
                    R(end+1) = row(6, 'detect_block (default green)', 'INFO', ...
                        'no green blob - fine if no green block is in view');
                else
                    R(end+1) = row(6, 'detect_block (default green)', 'PASS', ...
                        sprintf('centroid (%.1f, %.1f) px, %d mask px', uv, nnz(mask)));
                    try, hold on; plot(uv(1), uv(2), 'r+', 'MarkerSize', 20, 'LineWidth', 2); catch, end
                end
            catch e
                R(end+1) = row(6, 'detect_block', 'FAIL', e.message);
            end
        catch e
            R(end+1) = row(6, 'capture_realsense', 'FAIL', e.message);
        end
    end
    printRows(R([R.section] == 6));

    %% ===================================================================
    %  SECTION 7 - LAB 6: GENAI API
    %  ===================================================================
    banner('7  LAB 6 - GEMINI API PRE-FLIGHT');
    if opts.SkipGenAI
        R(end+1) = row(7, 'Gemini API', 'SKIP', 'SkipGenAI');
    elseif isempty(lab6) || isempty(which('gemini_generate'))
        R(end+1) = row(7, 'Gemini API', 'SKIP', 'Lab 6 code folder (gemini_generate.m) not found');
    else
        try
            [txt, raw] = gemini_generate("Reply with exactly five words that describe a collaborative robot.");
            R(end+1) = row(7, 'gemini_generate (text)', 'PASS', ...
                sprintf('"%s"  [model %s]', strtrim(txt), getf(raw, 'modelVersion', '?')));
        catch e
            R(end+1) = row(7, 'gemini_generate (text)', 'FAIL', e.message);
        end
        if ~isempty(img)
            try
                t = tic;
                [uv, items] = vlm_point(img, "the most prominent object on the table");
                R(end+1) = row(7, 'vlm_point on camera frame', pf(~isempty(uv)), ...
                    sprintf('%d point(s), first at (%.0f, %.0f) px "%s" in %.1f s', ...
                    size(uv,1), uv(1,1), uv(1,2), items(1).label, toc(t)));
                if ~isempty(uv)
                    figure('Name', 'Smoke test - VLM point'); imshow(img); hold on;
                    plot(uv(:,1), uv(:,2), 'yo', 'MarkerSize', 16, 'LineWidth', 2);
                    title(sprintf('vlm\\_point: %s', items(1).label));
                    saveas(gcf, fullfile(logDir, 'vlm_point.png'));
                end
            catch e
                R(end+1) = row(7, 'vlm_point on camera frame', 'FAIL', e.message);
            end
        else
            R(end+1) = row(7, 'vlm_point on camera frame', 'SKIP', 'no camera frame');
        end
    end
    printRows(R([R.section] == 7));

    finish(R, logDir);
    results = R;
end

%% ========================================================================
%  helpers
%  ========================================================================
function finish(R, logDir)
    banner('SUMMARY');
    printRows(R);
    nFail = nnz(strcmp({R.status}, 'FAIL'));
    nWarn = nnz(strcmp({R.status}, 'WARN'));
    nSkip = nnz(strcmp({R.status}, 'SKIP'));
    fprintf('\n  %d FAIL, %d WARN, %d SKIP out of %d checks.\n', nFail, nWarn, nSkip, numel(R));
    fid = fopen(fullfile(logDir, 'results.json'), 'w');
    fwrite(fid, jsonencode(R, 'PrettyPrint', true)); fclose(fid);
    fprintf('  Log, results.json and images are in:\n  %s\n\n', logDir);
end

function r = row(section, name, status, detail)
    r = struct('section', section, 'name', char(name), 'status', char(status), 'detail', char(string(detail)));
end

function printRows(R)
    for k = 1:numel(R)
        fprintf('  [%-4s] %-40s %s\n', R(k).status, R(k).name, R(k).detail);
    end
    fprintf('\n');
end

function s = pf(ok)
    if ok, s = 'PASS'; else, s = 'FAIL'; end
end

function out = ternary(c, a, b)
    if c, out = a; else, out = b; end
end

function banner(txt)
    fprintf('\n============================================================\n');
    fprintf('  %s\n', txt);
    fprintf('============================================================\n');
end

function s = lastLine(txt)
    lines = strsplit(strtrim(txt), newline);
    s = lines{end};
end

function ok = waitForArrival(ur, readFcn, target, idx, tol)
%WAITFORARRIVAL  Same helper as in the lab scripts: poll until elements idx are within
%   tol of target, no longer changing, and the server script reports its last motion
%   command finished (2026-11-04: without that check the next command can be sent while
%   the server is still inside the previous move and is dropped); then pause briefly.
%   Gives up after 60 s.
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

function d = findLab(root, patterns)
    d = '';
    for k = 1:numel(patterns)
        hits = dir(fullfile(root, patterns{k}));
        hits = hits([hits.isdir]);
        if ~isempty(hits)
            if strcmp(hits(1).name, '.')      % pattern named the folder itself (e.g. Lab 05*/Code)
                d = hits(1).folder;
            else
                d = fullfile(hits(1).folder, hits(1).name);
            end
            return
        end
    end
end

function [S, M] = urScrewModel(p)
%URSCREWMODEL  Instructor solution to Lab 3 (same as UR_FK_Lab_KEY).
    d1=p.d1; a2=p.a2; a3=p.a3; d4=p.d4; d5=p.d5; d6=p.d6;
    S = [ 0, 0,  1,               0, 0, 0;
          0, 1,  0,             -d1, 0, 0;
          0, 1,  0,        -(d1+a2), 0, 0;
          0, 1,  0,     -(d1+a2+a3), 0, 0;
          0, 0, -1,              d4, 0, 0;
          0, 1,  0,  -(d1+a2+a3+d5), 0, 0 ].';
    M = [ -1,  0,  0,            0;
           0,  0, -1,     -(d4+d6);
           0, -1,  0,  d1+a2+a3+d5;
           0,  0,  0,            1 ];
end

function e = rotm2eulZYX(R)
%ROTM2EULZYX  [yaw pitch roll] for R = Rz(yaw)*Ry(pitch)*Rx(roll).
    pitch = asin(-R(3,1));
    if abs(cos(pitch)) > 1e-9
        yaw  = atan2(R(2,1), R(1,1));
        roll = atan2(R(3,2), R(3,3));
    else
        yaw  = atan2(-R(1,2), R(2,2));
        roll = 0;
    end
    e = [yaw pitch roll];
end

function v = rotm2rotvec(R)
%ROTM2ROTVEC  Axis-angle rotation vector (UR's native orientation format).
    ang = acos(max(-1, min(1, (trace(R) - 1) / 2)));
    if ang < 1e-9
        v = [0 0 0];
    elseif abs(pi - ang) < 1e-6
        [~, k] = max(diag(R));
        ax = sqrt(max(0, (R(k,k) + 1) / 2)) * ones(1,3);
        for j = 1:3, if j ~= k, ax(j) = R(k,j) / (2 * ax(k)); end, end
        v = ang * ax / norm(ax);
    else
        ax = [R(3,2)-R(2,3), R(1,3)-R(3,1), R(2,1)-R(1,2)] / (2*sin(ang));
        v = ang * ax;
    end
end

function v = getf(s, f, default)
    if isfield(s, f), v = s.(f); else, v = default; end
end

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end
