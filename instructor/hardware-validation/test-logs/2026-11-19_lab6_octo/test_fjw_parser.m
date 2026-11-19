function test_fjw_parser()
% Offline check of the toolbox parser for followJointWaypoints: no robot, no motion.
% Same arguments UR_VLA_Octo_Prototype>moveThrough now sends (6 x N matrix, no times with blend).
    p = codertarget.urseries.internal.manipulatorRTDEInterfaceInputParser;
    d.Velocity = 0.3; d.Acceleration = 0.5; d.BlendRadius = 0;
    q0 = deg2rad([3.59 -101.4 -98.88 -69.58 89.36 180.9]);
    Q = [q0; q0 + deg2rad([1 -2 1 1 0 0]); q0 + deg2rad([2 -4 2 2 0 0]); q0 + deg2rad([3 -5 3 2 0 0])];
    fprintf('matrix sent: %d x %d\n', size(Q'));
    try
        r = p.parseFollowJointWayPoints(d, Q', 'Velocity', 0.3, 'Acceleration', 0.5, 'BlendRadius', 0.0056);
        fprintf('blend call parsed: JointWaypoints %s, WaypointTimes %s, Velocity %.2f, Acceleration %.2f, BlendRadius %.4f\n', ...
            mat2str(size(r.JointWaypoints)), mat2str(r.WaypointTimes), r.Velocity, r.Acceleration, r.BlendRadius);
    catch e
        fprintf('blend call FAILED: %s\n', e.message);
    end
    try
        r = p.parseFollowJointWayPoints(d, Q', 'WaypointTimes', [0 0.6 1.2 1.8], 'Velocity', 0.3, 'Acceleration', 0.5);
        fprintf('timed call parsed: WaypointTimes %s, BlendRadius %.4f\n', mat2str(r.WaypointTimes), r.BlendRadius);
    catch e
        fprintf('timed call FAILED: %s\n', e.message);
    end
    try
        p.parseFollowJointWayPoints(d, Q, 'WaypointTimes', [0 0.6 1.2 1.8]);
        fprintf('N x 6 call parsed (unexpected)\n');
    catch e
        fprintf('N x 6 call rejected as in the live run: %s\n', e.message);
    end
end
