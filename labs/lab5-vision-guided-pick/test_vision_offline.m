function test_vision_offline()
%TEST_VISION_OFFLINE  Check the vision math with no camera and no robot.
%
%   Verifies detect_block on synthetic images (including the red hue
%   wrap-around) and fit_pixel_to_base / pixel_to_base round trips.
%   Everything here must PASS before the lab is handed out.

    fails = 0;

    % --- synthetic green block ---
    img = uint8(120 * ones(480, 640, 3));
    img(200:280, 300:400, 1) = 30;  img(200:280, 300:400, 2) = 200; img(200:280, 300:400, 3) = 40;
    [uv, mask] = detect_block(img, [0.25 0.35 0.25], [0.45 1.0 1.0], 200);
    err = norm(uv - [350 240]);
    fails = fails + check('green block centroid', err < 1.5, sprintf('err %.2f px', err));
    fails = fails + check('green mask area sane', abs(nnz(mask) - 81*101) < 50, sprintf('area %d', nnz(mask)));

    % --- synthetic red block (hue wrap-around) ---
    img2 = uint8(120 * ones(480, 640, 3));
    img2(100:150, 100:180, 1) = 220; img2(100:150, 100:180, 2) = 30; img2(100:150, 100:180, 3) = 30;
    uv2 = detect_block(img2, [0.95 0.4 0.3], [0.05 1.0 1.0], 200);
    err2 = norm(uv2 - [140 125]);
    fails = fails + check('red block (hue wrap)', err2 < 1.5, sprintf('err %.2f px', err2));

    % --- nothing detected returns NaN ---
    uv3 = detect_block(img2, [0.55 0.5 0.5], [0.70 1.0 1.0], 200);
    fails = fails + check('no-detection returns NaN', all(isnan(uv3)), mat2str(uv3));

    % --- affine fit: exact recovery, then noisy ---
    A0 = [ 0.0004  0.00002  -0.180 ;
          -0.00003 -0.00041  -0.520 ];             % plausible px->m map
    rng(1);
    UV = [rand(6,1)*640, rand(6,1)*480];
    XY = (A0 * [UV, ones(6,1)]')';
    [A, ~, rms_mm] = fit_pixel_to_base(UV, XY);
    fails = fails + check('affine exact recovery', norm(A - A0, 'fro') < 1e-12 && rms_mm < 1e-9, ...
                          sprintf('rms %.2e mm', rms_mm));
    XYn = XY + 0.001 * randn(size(XY));            % 1 mm noise
    [An, ~, rmsn] = fit_pixel_to_base(UV, XYn);
    p  = pixel_to_base(An, [320 240]);
    pt = (A0 * [320; 240; 1])';
    fails = fails + check('noisy fit stays close', rmsn < 3 && norm(p - pt) < 0.004, ...
                          sprintf('rms %.2f mm, pred err %.1f mm', rmsn, norm(p - pt)*1000));

    fprintf('\n%s\n', repmat('-', 1, 44));
    if fails == 0, fprintf('ALL OFFLINE VISION TESTS PASS\n\n');
    else, fprintf(2, '%d TEST(S) FAILED\n\n', fails); end
end

function bad = check(name, ok, detail)
    fprintf('%-28s %s  (%s)\n', name, ternary(ok, 'PASS', '*** FAIL ***'), detail);
    bad = ~ok;
end
function out = ternary(c, a, b), if c, out = a; else, out = b; end, end
