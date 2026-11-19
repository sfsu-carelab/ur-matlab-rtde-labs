function test_plan_waypoints()
% Read-only check of the chunk planner against the live robot: no motion.
% Copies planWaypoints / poseToJoints from UR_VLA_Octo_Prototype.m (local functions there).
    ur = urRTDEClient('192.168.1.10', 'CobotName', 'universalUR3e');
    q0 = readJointConfiguration(ur);
    cur = readCartesianPose(ur);
    fprintf('robot joints (deg): [%s]\nflange (mm): [%.1f %.1f %.1f]\n', join(string(round(rad2deg(q0), 2)), ' '), 1000*cur(4:6));
    % a fake chunk like run 1: down and a little +X / -Y, 4 steps, one tiny step to test merging
    D = [0.008 -0.006 -0.017; 0.006 -0.006 -0.011; 0.0005 0.0005 -0.001; 0.002 0 -0.016];
    T = repmat(cur, 4, 1); T(:, 4:6) = cur(4:6) + cumsum(D, 1);
    t = tic;
    [Q, T2, times, blend] = planWaypoints(ur, T, q0, 0.6, 0.01);
    fprintf('planWaypoints: %.2f s, %d of 4 waypoints kept, times [%s], blend %.4f m\n', toc(t), size(Q, 1), join(string(times), ' '), blend);
    robot = ur.RigidBodyTree; ee = robot.BodyNames{end};
    qprev = q0;
    for j = 1:size(Q, 1)
        p = tform2trvec(getTransform(robot, Q(j, :), ee));
        fprintf('  wp %d: target (%.1f %.1f %.1f) mm, FK of IK (%.1f %.1f %.1f) mm, err %.2f mm, max joint step %.2f deg\n', ...
            j, 1000*T2(j, 4:6), 1000*p, 1000*norm(p - T2(j, 4:6)), max(abs(rad2deg(Q(j, :) - qprev))));
        qprev = Q(j, :);
    end
    % NOTE: no followJointWaypoints call here, even a malformed one: hard rule 1, the batch
    % session never moves the robot. The option names come from the function's help text.
end

function [Q, T, times, blend] = planWaypoints(ur, T, q0, stepTime, blend)
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
        error('test:ikFailed', 'No joint solution near the current pose; pose error %.2g.', info.PoseErrorNorm);
    end
end
