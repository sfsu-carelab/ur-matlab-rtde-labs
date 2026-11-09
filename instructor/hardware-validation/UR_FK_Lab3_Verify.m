function UR_FK_Lab3_Verify(opts)
%UR_FK_LAB3_VERIFY  Instructor run of Lab 3 Part 4 (Table 6) on the real robot.
%
%   Run from the MATLAB DESKTOP with the e-stop in hand:
%       UR_FK_Lab3_Verify
%       UR_FK_Lab3_Verify(DryRun=true)     % prints the plan, moves nothing
%
%   For each Table 6 pose: convert screw angles -> pendant angles with
%   screw2hw, move there with sendJointConfigurationAndWait, read the joint
%   angles over RTDE and the robot's own TCP pose from the controller's
%   secondary interface (port 30002, the same numbers the pendant shows),
%   run fk_space on the SCREW angles exactly as the manual tells students
%   to, and log FK vs robot. Returns to the starting pose at the end.
%
%   Needs: URServerScript_Robotiq2F_PolyScopeX.script PLAYING on the pendant,
%   speed slider at 100 percent (or at least 50), active TCP = flange (0,0,0).

arguments
    opts.DryRun   (1,1) logical = false
    opts.RobotIP  (1,1) string  = "192.168.1.10"
    opts.EndTime  (1,1) double  = 6      % seconds scheduled per move
    opts.MinZ     (1,1) double  = 0.20   % refuse any pose with a link point lower (m)
    opts.MinX     (1,1) double  = -0.18  % side wall on -x: x = -0.17 reached safely, -0.26 was e-stopped
    opts.MaxY     (1,1) double  =  0.06  % back wall on +y: no link point beyond this
end

% this file lives in <repo>/instructor/hardware-validation/
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'labs', 'lab3-forward-kinematics'));
logDir = fullfile(root, 'instructor', 'hardware-validation', 'test-logs', ...
                  [char(datetime('now', 'Format', 'yyyy-MM-dd_HHmmss')) '_lab3_task4']);

theta_home = [0, -90, 0, -90, 0, 0];

% Table 6 poses in SCREW angles (deg). 1 and 2 are the manual's; 3 to 6 are
% instructor picks that between them move every joint. All six were run on
% the UR3e on 2026-11-06 (test-logs/2026-11-06_151343_lab3_task4 and
% 2026-11-06_152626_lab3_task4): worst error 1.19 mm, 0.38 deg.
%
% Room note (SEC 414, 2026-11-06): walls on the robot's +y side (back, where
% the cable exits) and -x side. A pose at x = -0.26 m was e-stopped, so the
% keep-out box below refuses anything past x = MinX or y = MaxY. Leaning the
% arm toward +x and then rotating the base POSITIVE swings it toward +y (the
% back wall); rotate the base negative instead to swing toward -y.
% 2026-11-09: the lab now uses the robot's own joint directions, so these are
% the SAME six physical poses (same pendant angles) as the 2026-11-06 runs,
% rewritten as screw angle = pendant angle - theta_home.
poses = [  0    0    0    0    0    0;    % 1  home (upright)
           0   45  -45    0    0    0;    % 2  Rev2 manual's example
          30   30  -60   30    0    0;    % 3  base + wrist 1 (Rev3 manual's Task 3 example)
         -30  -30   30  -30    0    0;    % 4  base -30, lean +x, wrist 1
         -20  -20  -20   40  -60    0;    % 5  wrist 2 in play
         -45  -30   30   30   60  -90 ];  % 6  all six joints
% keep-out: all link points must satisfy x >= MinX, y <= MaxY, z >= MinZ

% --- instructor solution (same as UR_FK_Lab_KEY) ---------------------------
p = ur_link_lengths("UR3e");
L1=p.L1; L2=p.L2; L3=p.L3; L4=p.L4; L5=p.L5; L6=p.L6;
S = [0  0 1            0 0 0;
     0 -1 0           L1 0 0;
     0 -1 0        L1+L2 0 0;
     0 -1 0     L1+L2+L3 0 0;
     0  0 1          -L4 0 0;
     0 -1 0  L1+L2+L3+L5 0 0].';
M = [-1 0 0 0; 0 0 -1 -(L4+L6); 0 -1 0 L1+L2+L3+L5; 0 0 0 1];

% --- plan ------------------------------------------------------------------
n = size(poses, 1);
fprintf('\n  Lab 3 Task 4 verification plan (UR3e, EndTime=%g s)\n', opts.EndTime);
fprintf('  %-4s %-28s %-28s %-26s  %s\n', 'Pose', 'screw angles (deg)', 'pendant angles (deg)', 'FK flange xyz (m)', 'link envelope: min x / max y / min z (m)');
hw = zeros(n, 6); pFK = zeros(n, 3); bad = false;
for k = 1:n
    hw(k,:) = screw2hw(poses(k,:), theta_home);
    T = fk_space(S, M, poses(k,:));
    pFK(k,:) = T(1:3,4)';
    P = linkPoints(S, M, poses(k,:), p);          % elbow, wrist 1, wrist 2, wrist 3, flange
    env = [min(P(1,:)), max(P(2,:)), min(P(3,:))];
    ok  = env(1) >= opts.MinX && env(2) <= opts.MaxY && env(3) >= opts.MinZ;
    bad = bad || ~ok;
    fprintf('  %-4d %-28s %-28s [%7.4f %7.4f %7.4f]  %7.3f / %7.3f / %7.3f  %s\n', ...
        k, vec(poses(k,:)), vec(hw(k,:)), pFK(k,:), env, ternary(ok, 'ok', '<-- OUTSIDE KEEP-OUT'));
end
if bad
    error('A planned pose leaves the keep-out box (x >= %.2f, y <= %.2f, z >= %.2f). Not moving.', opts.MinX, opts.MaxY, opts.MinZ);
end
if opts.DryRun
    fprintf('\n  DryRun: nothing sent to the robot.\n\n'); return
end

fprintf('\n  The robot WILL MOVE through these %d poses and then return to where it is now.\n', n);
fprintf('  Pendant: server script PLAYING, slider at 100%%, workspace clear, e-stop in hand.\n');
if ~strcmpi(input('  Type "yes" to start: ', 's'), 'yes')
    fprintf('  Aborted. Robot will not move.\n'); return
end

% --- connect ---------------------------------------------------------------
ur = urRTDEClient(char(opts.RobotIP), 'CobotName', 'universalUR3e');
q_start = readJointConfiguration(ur);
fprintf('\n  Connected. Start joints (deg): [%s]\n', vec(rad2deg(q_start)));
sec0 = readSecondary(char(opts.RobotIP));
if sec0.ok
    fprintf('  Active TCP offset on pendant: [%s] m\n', vec(sec0.tcpOffset(1:3)));
    if norm(sec0.tcpOffset(1:3)) > 1e-6
        fprintf(2, '  WARNING: active TCP is not the flange; the FK will be compared with the offset applied.\n');
    end
end

mkdir(logDir);
logf = fullfile(logDir, 'lab3_task4_verification.txt');
fid = fopen(logf, 'w');
cleanupObj = onCleanup(@() fclose(fid));
out = @(varargin) logboth(fid, varargin{:});
out('Lab 3 Task 4 hardware verification - %s - UR3e at %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), opts.RobotIP);
out('FK = fk_space(S_list, M, screw angles) with the instructor S_list/M; robot TCP from the controller (port 30002, base frame).\n');
out('EndTime = %g s per move. Active TCP offset: [%s] m\n\n', opts.EndTime, vec(sec0.tcpOffset(1:3)));
out('%-4s | %-24s | %-24s | %-26s | %-26s | %-26s | %-8s | %-8s | %-8s\n', 'Pose', 'screw angles (deg)', 'pendant angles (deg)', 'measured joints (deg)', 'FK position (m)', 'robot TCP (m)', 'err mm', 'ori deg', 'jnt deg');
out('%s\n', repmat('-', 1, 190));

% --- run -------------------------------------------------------------------
results = struct('pose', {}, 'screw', {}, 'hw', {}, 'meas', {}, 'fk', {}, 'robot', {}, 'err_mm', {}, 'ori_deg', {}, 'joint_err_deg', {});
try
    for k = 1:n
        fprintf('\n  [%d/%d] moving to pendant angles [%s] ...\n', k, n, vec(hw(k,:)));
        moveTo(ur, hw(k,:), opts.EndTime);
        pause(1.0);                                  % let the arm settle fully
        q    = readJointConfiguration(ur);           % rad
        sec  = readSecondary(char(opts.RobotIP));
        qdeg = rad2deg(q(:)');
        T    = fk_space(S, M, poses(k,:));           % manual's method: FK of the SCREW angles
        Rf   = T(1:3,1:3); pf = T(1:3,4);
        if sec.ok
            off  = sec.tcpOffset(1:3); off = off(:);
            pTCP = pf + Rf * off;
            Rrob = rotvec2rotm(sec.tcp(4:6));
            Rfk  = Rf * rotvec2rotm(sec.tcpOffset(4:6));
            err  = norm(pTCP - sec.tcp(1:3)') * 1000;
            ori  = rad2deg(acos(max(-1, min(1, (trace(Rfk' * Rrob) - 1) / 2))));
            robotStr = sprintf('[%7.4f %7.4f %7.4f]', sec.tcp(1:3));
        else
            pTCP = pf; err = NaN; ori = NaN; robotStr = 'n/a (30002 read failed)';
        end
        jerr = max(abs(wrap180(qdeg - hw(k,:))));
        out('%-4d | %-24s | %-24s | %-26s | [%7.4f %7.4f %7.4f] | %-26s | %8.2f | %8.3f | %8.3f\n', ...
            k, vec(poses(k,:)), vec(hw(k,:)), vec(round(qdeg, 2)), pTCP, robotStr, err, ori, jerr);
        results(end+1) = struct('pose', k, 'screw', poses(k,:), 'hw', hw(k,:), 'meas', qdeg, ...
            'fk', pTCP', 'robot', sec.tcp, 'err_mm', err, 'ori_deg', ori, 'joint_err_deg', jerr); %#ok<AGROW>
    end
    fprintf('\n  Returning to the start pose ...\n');
    moveTo(ur, rad2deg(q_start(:)'), opts.EndTime);
catch e
    out('\nABORTED at pose %d: %s\n', numel(results) + 1, e.message);
    rethrow(e);
end

% --- summary ---------------------------------------------------------------
errs = [results.err_mm]; oris = [results.ori_deg];
out('\nWorst position error %.2f mm, worst orientation error %.3f deg over %d poses.\n', max(errs), max(oris), numel(results));
if max(errs) < 3 && max(oris) < 0.5
    out('RESULT: PASS - the Lab 3 FK matches the robot at every Table 6 pose.\n');
else
    out('RESULT: CHECK - see the table.\n');
end
save(fullfile(logDir, 'results.mat'), 'results', 'poses', 'hw', 'theta_home', 'S', 'M');
fprintf('\n  Log written to %s\n\n', logf);
clear ur
end

% ===========================================================================
function moveTo(ur, q_deg, endTime)
    q = deg2rad(q_deg);
    sendJointConfigurationAndWait(ur, q, EndTime = endTime);
    ok = waitForArrival(ur, @() readJointConfiguration(ur), q, 1:6, deg2rad(0.5));
    if ~ok
        error('Robot did not reach [%s] deg within 60 s. Server script playing? Slider near zero? Protective stop?', vec(q_deg));
    end
end

function ok = waitForArrival(ur, readFcn, target, idx, tol)
    % same pattern as the labs: arrived, settled, and the server script idle
    maxWait = 60; t0 = tic; prev = readFcn();
    while toc(t0) < maxWait
        pause(0.2); cur = readFcn();
        arrived = max(abs(wrapPi(cur(idx) - target(idx)))) < tol && max(abs(cur(idx) - prev(idx))) < tol;
        if arrived && serverIdle(ur), pause(0.3); ok = true; return; end
        prev = cur;
    end
    ok = false;
end

function idle = serverIdle(ur)
    try
        [~, state] = readMotionStatus(ur); idle = ~strcmpi(state, 'Executing');
    catch
        idle = false;
    end
end

function sec = readSecondary(ip)
% One ROBOT_STATE message (type 16) from port 30002; CARTESIAN_INFO (type 4)
% holds X Y Z Rx Ry Rz then the active TCP offset, big-endian doubles.
    sec = struct('ok', false, 'tcp', nan(1,6), 'tcpOffset', zeros(1,6));
    try
        c = tcpclient(ip, 30002, 'Timeout', 5);
        buf = uint8([]); t0 = tic;
        while toc(t0) < 4
            pause(0.25); nb = c.NumBytesAvailable;
            if nb > 0, buf = [buf, read(c, nb, 'uint8')]; end %#ok<AGROW>
            if numel(buf) > 3000, break; end
        end
        clear c
    catch
        return
    end
    i = 1; n = numel(buf);
    while i + 4 <= n
        len = be_int32(buf(i:i+3)); typ = buf(i+4);
        if len < 5 || i + len - 1 > n, break; end
        if typ == 16
            j = i + 5;
            while j + 4 <= i + len - 1
                slen = be_int32(buf(j:j+3)); styp = buf(j+4);
                if slen < 5, break; end
                if styp == 4 && slen >= 5 + 12*8
                    d = zeros(1, 12);
                    for k = 1:12, d(k) = be_double(buf(j+5+(k-1)*8 : j+4+k*8)); end
                    sec.tcp = d(1:6); sec.tcpOffset = d(7:12); sec.ok = true; return
                end
                j = j + slen;
            end
        end
        i = i + len;
    end
end

function P = linkPoints(S, M, theta_deg, p)
% Positions of the elbow, wrist 1, wrist 2, wrist 3 axes and the flange for the
% given screw angles. Point i rides on joints 1..i, so apply the first i
% exponentials to its home position.
    home = [0, 0, p.L1 + p.L2;                      % elbow (joint 3 axis)
            0, 0, p.L1 + p.L2 + p.L3;               % wrist 1 (joint 4 axis)
            0, -p.L4, p.L1 + p.L2 + p.L3;           % wrist 2 (joint 5 axis)
            0, -p.L4, p.L1 + p.L2 + p.L3 + p.L5;    % wrist 3 (joint 6 axis)
            M(1:3,4)'];                             % flange
    nj = [2 3 4 5 6];
    P = zeros(3, size(home, 1));
    for i = 1:size(home, 1)
        T = eye(4);
        for j = 1:nj(i)
            T = T * fk_space(S(:,j), eye(4), theta_deg(j));
        end
        q = T * [home(i,:)'; 1];
        P(:,i) = q(1:3);
    end
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end

function logboth(fid, varargin)
    fprintf(1, varargin{:});
    fprintf(fid, varargin{:});
end
function v = be_int32(b),  v = double(swapbytes(typecast(uint8(b(:)'), 'int32'))); end
function v = be_double(b), v = swapbytes(typecast(uint8(b(:)'), 'double')); end
function s = vec(x), s = ['[' strtrim(sprintf('%g ', round(x(:)', 2))) ']']; end
function a = wrapPi(a),  a = mod(a + pi, 2*pi) - pi; end
function a = wrap180(a), a = mod(a + 180, 360) - 180; end
function R = rotvec2rotm(r)
    r = r(:); ang = norm(r);
    if ang < 1e-12, R = eye(3); return; end
    k = r / ang; K = [0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0];
    R = eye(3) + sin(ang)*K + (1-cos(ang))*K^2;
end
