function run_self_tests(S_list, M, p)
%RUN_SELF_TESTS  Check a student's S_list and M against known closed forms.
%
%   Every joint is now exercised by at least one position or orientation
%   check, so a sign flip or a wrong v on ANY joint produces a FAIL here
%   rather than an unexplained error at the robot.

    if any(isnan(S_list(:))) || any(isnan(M(:)))
        fprintf(2, '  S_list and/or M still contain NaN - fill in PART 2 first.\n\n');
        return
    end

    d1=p.d1; a2=p.a2; a3=p.a3; d4=p.d4; d5=p.d5; d6=p.d6;
    tol = 1e-10;
    fails = 0;

    fprintf('============================================================\n');
    fprintf('  %s Forward Kinematics - Self Tests\n', p.model);
    fprintf('============================================================\n\n');

    % TEST 1: home configuration - every exponential is the identity, so T == M.
    T1   = fk_space(S_list, M, [0 0 0 0 0 0]);
    fails = fails + report(1, 'Home (all zeros)', M(1:3,4), T1(1:3,4), tol);

    % TEST 2: shoulder +90 deg - arm swings down to horizontal along +x.
    T2   = fk_space(S_list, M, [0 90 0 0 0 0]);
    exp2 = [a2+a3+d5; -(d4+d6); d1];
    fails = fails + report(2, 'Shoulder +90 deg', exp2, T2(1:3,4), tol);

    % TEST 3: base +90 deg - the wrist offset swings from -y round to +x.
    T3   = fk_space(S_list, M, [90 0 0 0 0 0]);
    exp3 = [d4+d6; 0; d1+a2+a3+d5];
    fails = fails + report(3, 'Base +90 deg', exp3, T3(1:3,4), tol);

    % TEST 4: shoulder +45, elbow -90 - a two-joint pose with a closed form.
    T4   = fk_space(S_list, M, [0 45 -90 0 0 0]);
    exp4 = [(a2-a3-d5)*sqrt(2)/2; -(d4+d6); d1+(a2+a3+d5)*sqrt(2)/2];
    fails = fails + report(4, 'Shoulder +45, Elbow -90', exp4, T4(1:3,4), tol);

    % TEST 5: wrist joints individually, then a general pose.
    fprintf('TEST 5: Wrist joints and general pose\n');

    %  (a) wrist 1 alone swings the tool forward about its own axis.
    Ta   = fk_space(S_list, M, [0 0 0 90 0 0]);
    expa = [d5; -(d4+d6); d1+a2+a3];
    fa   = subreport('  (a) Wrist 1 (theta4 = +90)', expa, Ta(1:3,4), tol);

    %  (b) wrist 2 alone swings the flange offset around its vertical axis.
    Tb   = fk_space(S_list, M, [0 0 0 0 90 0]);
    expb = [-d6; -d4; d1+a2+a3+d5];
    fb   = subreport('  (b) Wrist 2 (theta5 = +90)', expb, Tb(1:3,4), tol);

    %  (c) wrist 3's axis passes through the tool point, so rotating it must
    %      NOT move the position at all. A wrong v6 fails this immediately.
    Tc   = fk_space(S_list, M, [0 0 0 0 0 90]);
    fc   = subreport('  (c) Wrist 3 (theta6 = +90): position unchanged', M(1:3,4), Tc(1:3,4), tol);

    %  (d) general pose: check the ORIENTATION. Rotations do not depend on
    %      the link lengths, so this matrix is the same for every UR model.
    Td = fk_space(S_list, M, [30 45 -60 45 -30 60]);
    Rexp = [ 0.1752404736  -0.5625000000   0.8080127019;
            -0.1875000000  -0.8247595264  -0.5334936491;
             0.9665063509  -0.0580127019  -0.2500000000];
    errd = norm(Td(1:3,1:3) - Rexp, 'fro');
    fd   = errd >= tol;
    fprintf('  (d) General pose [30 45 -60 45 -30 60]: orientation error %.2e  %s\n', ...
            errd, pass_fail(errd, tol));

    %  (e) reach sanity: the tool can never be further from the base axis
    %      than the arm is long.
    reach = norm(Td([1 2],4));
    lim   = a2 + a3 + d5 + d4 + d6;
    fe    = max(0, reach - lim) >= tol;
    fprintf('  (e) Reach: %.5f m (max %.5f m)  %s\n\n', ...
            reach, lim, pass_fail(max(0, reach-lim), tol));

    fails = fails + fa + fb + fc + fd + fe;

    fprintf('============================================================\n');
    if fails == 0
        fprintf('  ALL TESTS PASS - your S_list and M are consistent with the\n');
        fprintf('  robot''s geometry on every joint.\n');
    else
        fprintf(2, '  %d CHECK(S) FAILED - the failing test names which joints moved;\n', fails);
        fprintf(2, '  recheck those rows of S_list (and M for tests 1 and 5d).\n');
    end
    fprintf('============================================================\n\n');

    assignin('base', 'S_list', S_list);
    assignin('base', 'M', M);
    fprintf('S_list and M saved to the base workspace.\n');
    fprintf('You can now call:  T = fk_space(S_list, M, [t1 t2 t3 t4 t5 t6])\n');
    fprintf('and convert to pendant angles with:  theta_hw = screw2hw(theta_screw, theta_home)\n\n');
end

function bad = report(n, name, expected, computed, tol)
    err = norm(computed - expected);
    fprintf('TEST %d: %s\n', n, name);
    fprintf('  Expected:  [%.5f, %.5f, %.5f]\n', expected);
    fprintf('  Computed:  [%.5f, %.5f, %.5f]\n', computed);
    fprintf('  Error:     %.2e m  %s\n\n', err, pass_fail(err, tol));
    bad = err >= tol;
end

function bad = subreport(name, expected, computed, tol)
    err = norm(computed - expected);
    fprintf('%s: expected [%.5f, %.5f, %.5f], got [%.5f, %.5f, %.5f], err %.2e  %s\n', ...
            name, expected, computed, err, pass_fail(err, tol));
    bad = err >= tol;
end

function s = pass_fail(err, tol)
    if err < tol, s = 'PASS'; else, s = '*** FAIL ***'; end
end
