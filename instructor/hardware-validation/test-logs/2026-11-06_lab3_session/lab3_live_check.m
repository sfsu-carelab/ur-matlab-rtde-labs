function lab3_live_check()
%LAB3_LIVE_CHECK  Read-only Lab 3 check against the live UR3e (no motion).
%   Reads joints + pose over RTDE, reads the robot's own TCP pose (what the
%   pendant shows) from the secondary client interface on port 30002, runs
%   the Lab 3 PoE FK at the live joint angles and compares all three.

ip   = '192.168.1.10';
root = 'C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs';
addpath(fullfile(root, 'labs', 'lab3-forward-kinematics'));

p  = ur_link_lengths("UR3e");
d1=p.d1; a2=p.a2; a3=p.a3; d4=p.d4; d5=p.d5; d6=p.d6;
S = [0 0  1              0 0 0;
     0 1  0            -d1 0 0;
     0 1  0       -(d1+a2) 0 0;
     0 1  0    -(d1+a2+a3) 0 0;
     0 0 -1             d4 0 0;
     0 1  0 -(d1+a2+a3+d5) 0 0].';
M = [-1 0 0 0; 0 0 -1 -(d4+d6); 0 -1 0 d1+a2+a3+d5; 0 0 0 1];

fprintf('\n=== Lab 3 live check, %s ===\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

%% 1. Robot's own TCP pose from the secondary interface (port 30002)
sec = struct('ok', false);
try
    sec = readSecondary(ip);
    if sec.ok
        fprintf('\n[30002] robot TCP pose (base frame):   X Y Z = [%.4f %.4f %.4f] m   Rx Ry Rz = [%.4f %.4f %.4f] rad\n', sec.tcp);
        fprintf('[30002] active TCP offset on pendant:  [%.4f %.4f %.4f] m   rot [%.4f %.4f %.4f]\n', sec.tcpOffset);
    else
        fprintf('\n[30002] no CARTESIAN_INFO package found in %d bytes\n', sec.nbytes);
    end
catch e
    fprintf('\n[30002] read failed: %s\n', e.message);
end

%% 2. RTDE read
t = tic; ur = urRTDEClient(ip, 'CobotName', 'universalUR3e'); dt = toc(t);
fprintf('\n[RTDE] connected in %.2f s\n', dt);
q    = readJointConfiguration(ur);           % rad
pose = readCartesianPose(ur);                % [thetaz thetay thetax x y z]
theta_hw = rad2deg(q(:)');
fprintf('[RTDE] joints (pendant deg):  [%s]\n', join(string(round(theta_hw, 3)), ', '));
fprintf('[RTDE] readCartesianPose:     [%s]\n', join(string(round(pose, 4)), ', '));

%% 3. Lab 3 FK at the live angles
theta = hw2screw(theta_hw);
T  = fk_space(S, M, theta);
Rf = T(1:3,1:3); pF = T(1:3,4);
fprintf('\n[FK]   screw angles (deg):     [%s]\n', join(string(round(theta, 3)), ', '));
fprintf('[FK]   flange position (m):    [%.4f %.4f %.4f]\n', pF);
fprintf('[FK]   ZYX Euler (rad):        [%.4f %.4f %.4f]\n', rotm2eulZYX(Rf));
fprintf('[FK]   rotation vector (rad):  [%.4f %.4f %.4f]\n', rotm2rotvec(Rf));

%% 4. Comparisons
pRep = pose(4:6); pRep = pRep(:);
eModel = norm(pF - pRep) * 1000;
eEul   = max(abs(wrapToPi(rotm2eulZYX(Rf) - pose(1:3))));
fprintf('\n[CMP]  FK flange vs readCartesianPose (model vs model): %.2f mm, Euler diff %.2e rad\n', eModel, eEul);

if sec.ok
    off  = sec.tcpOffset(1:3); off = off(:);
    Roff = rotvec2rotm(sec.tcpOffset(4:6));
    pTCP = pF + Rf * off;
    Rtcp = Rf * Roff;
    eHW  = norm(pTCP - sec.tcp(1:3)') * 1000;
    Rrob = rotvec2rotm(sec.tcp(4:6));
    eAng = rad2deg(acos(max(-1, min(1, (trace(Rtcp' * Rrob) - 1) / 2))));
    fprintf('[CMP]  FK TCP (flange + pendant TCP offset) vs ROBOT TCP: %.2f mm, orientation diff %.3f deg\n', eHW, eAng);
    fprintf('[CMP]  FK flange vs ROBOT TCP ignoring the offset:         %.2f mm\n', norm(pF - sec.tcp(1:3)') * 1000);
    if eHW < 3 && eAng < 0.5
        fprintf('\nRESULT: PASS - Lab 3 FK matches the robot''s own TCP readout.\n');
    else
        fprintf('\nRESULT: CHECK - see numbers above.\n');
    end
else
    if eModel < 1
        fprintf('\nRESULT: PASS (model vs model only; 30002 TCP not available)\n');
    else
        fprintf('\nRESULT: CHECK\n');
    end
end
clear ur
end

% ---------------------------------------------------------------------------
function sec = readSecondary(ip)
% Pull one ROBOT_STATE message (type 16) from the secondary interface and
% extract the CARTESIAN_INFO sub-package (type 4): X Y Z Rx Ry Rz, then the
% active TCP offset, all big-endian doubles.
c = tcpclient(ip, 30002, 'Timeout', 5);
buf = uint8([]);
t0 = tic;
while toc(t0) < 4
    pause(0.25);
    n = c.NumBytesAvailable;
    if n > 0, buf = [buf, read(c, n, 'uint8')]; end %#ok<AGROW>
    if numel(buf) > 3000, break; end
end
clear c
sec = struct('ok', false, 'nbytes', numel(buf), 'tcp', [], 'tcpOffset', []);
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
                for k = 1:12
                    d(k) = be_double(buf(j+5+(k-1)*8 : j+4+k*8));
                end
                sec.tcp = d(1:6); sec.tcpOffset = d(7:12); sec.ok = true;
                return
            end
            j = j + slen;
        end
    end
    i = i + len;
end
end

function v = be_int32(b), v = double(swapbytes(typecast(uint8(b(:)'), 'int32'))); end
function v = be_double(b), v = swapbytes(typecast(uint8(b(:)'), 'double')); end

function e = rotm2eulZYX(R)
e = [atan2(R(2,1), R(1,1)), atan2(-R(3,1), hypot(R(3,2), R(3,3))), atan2(R(3,2), R(3,3))];
end

function r = rotm2rotvec(R)
ang = acos(max(-1, min(1, (trace(R) - 1) / 2)));
if ang < 1e-9, r = [0 0 0]; return; end
ax = [R(3,2)-R(2,3), R(1,3)-R(3,1), R(2,1)-R(1,2)] / (2*sin(ang));
r = ax * ang;
end

function R = rotvec2rotm(r)
r = r(:); ang = norm(r);
if ang < 1e-12, R = eye(3); return; end
k = r / ang; K = [0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0];
R = eye(3) + sin(ang)*K + (1-cos(ang))*K^2;
end

function a = wrapToPi(a), a = mod(a + pi, 2*pi) - pi; end
