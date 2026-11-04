function test_vlm_offline()
%TEST_VLM_OFFLINE  Check the Lab 6 VLM plumbing with no robot (and no API key).
%
%   Part 1 runs with nothing but MATLAB: request building, reply parsing
%   (fenced and unfenced JSON, [y,x] -> [u,v] scaling), plan and verify
%   parsing, and the workspace bounds check.
%
%   Part 2 runs only if a Gemini API key is available (see gemini_generate):
%   it draws a synthetic scene with a red and a blue square, and checks that
%   the live model points inside the red square, plans a move from red to
%   blue, and judges a correctly-moved "after" image as a success.
%
%   Everything in Part 1 must PASS before the lab is handed out; Part 2 is
%   the pre-class check that the key, the network and the model id work.

    fails = 0;
    fprintf('\n===== PART 1: offline =====\n');

    % --- request body ----------------------------------------------------
    img = uint8(zeros(48, 64, 3));
    bodyTxt = gemini_generate("hello", {img, "note"}, DryRun=true, JSON=true, Model="m-test");
    b = jsondecode(bodyTxt);
    okB = isfield(b, 'contents') && numel(b.contents) == 1 && iscell(b.contents(1).parts) ...
        && numel(b.contents(1).parts) == 3 ...
        && isfield(b.contents(1).parts{1}, 'inline_data') ...
        && strcmp(b.contents(1).parts{1}.inline_data.mime_type, 'image/png') ...
        && strcmp(b.contents(1).parts{2}.text, 'note') ...
        && strcmp(b.contents(1).parts{3}.text, 'hello') ...
        && strcmp(b.generationConfig.responseMimeType, 'application/json') ...
        && b.generationConfig.thinkingConfig.thinkingBudget == 0;
    fails = fails + check('request body layout', okB, sprintf('%d bytes', strlength(bodyTxt)));

    % --- base64 PNG round trip -------------------------------------------
    d = b.contents(1).parts{1}.inline_data.data;
    bytes = matlab.net.base64decode(d);
    okPNG = numel(bytes) > 8 && isequal(bytes(1:4), uint8([137 80 78 71]));
    fails = fails + check('inline PNG is a PNG', okPNG, sprintf('%d bytes', numel(bytes)));

    % --- vlm_json ---------------------------------------------------------
    d1 = vlm_json(sprintf('```json\n[{"point": [500, 250], "label": "red block"}]\n```'));
    fails = fails + check('vlm_json strips fences', isstruct(d1) && d1.point(1) == 500, 'ok');
    d2 = vlm_json('Sure! Here it is: {"success": true, "diagnostics": "moved"} hope that helps');
    fails = fails + check('vlm_json finds embedded object', isstruct(d2) && d2.success == true, 'ok');

    % --- vlm_point scaling: [y x] 0-1000 -> [u v] pixels ------------------
    img = uint8(zeros(480, 640, 3));
    [uv, items] = vlm_point(img, "x", CannedResponse='[{"point": [500, 250], "label": "red block"}]');
    fails = fails + check('vlm_point y,x -> u,v', isequal(size(uv), [1 2]) && norm(uv - [160 240]) < 1e-9 ...
        && strcmp(items(1).label, 'red block'), mat2str(uv));
    uv2 = vlm_point(img, "x", CannedResponse='[]');
    fails = fails + check('vlm_point empty list', isempty(uv2), 'ok');
    uv3 = vlm_point(img, "x", MaxItems=3, CannedResponse= ...
        '[{"point":[100,100],"label":"a"},{"point":[900,900],"label":"b"}]');
    fails = fails + check('vlm_point multiple', isequal(size(uv3), [2 2]) && norm(uv3(2,:) - [576 432]) < 1e-9, mat2str(uv3));

    % --- vlm_plan ---------------------------------------------------------
    plan = vlm_plan(img, "x", CannedResponse= ...
        '{"pick": {"point": [250, 500], "label": "red block"}, "place": {"point": [750, 125], "label": "blue square"}, "reason": "r"}');
    fails = fails + check('vlm_plan parse', norm(plan.pick_uv - [320 120]) < 1e-9 && norm(plan.place_uv - [80 360]) < 1e-9 ...
        && strcmp(plan.place_label, 'blue square'), sprintf('pick %s place %s', mat2str(plan.pick_uv), mat2str(plan.place_uv)));
    planN = vlm_plan(img, "x", CannedResponse='{"pick": {"point": null, "label": ""}, "place": {"point": null, "label": ""}, "reason": "no red block visible"}');
    fails = fails + check('vlm_plan null points -> NaN', all(isnan(planN.pick_uv)) && contains(planN.reason, 'no red'), planN.reason);

    % --- vlm_verify -------------------------------------------------------
    [ok1, why1] = vlm_verify(img, img, "x", CannedResponse='{"success": true, "diagnostics": "done"}');
    [ok2, ~]    = vlm_verify(img, img, "x", CannedResponse='{"success": "false", "diagnostics": "still there"}');
    fails = fails + check('vlm_verify true/false', ok1 && ~ok2 && strcmp(why1, 'done'), 'ok');

    % --- bounds check -----------------------------------------------------
    XYcal = [-0.20 -0.50; -0.20 -0.30; 0.00 -0.50; 0.00 -0.30];
    [in1, ~] = xy_in_calibrated_area([-0.10 -0.40], XYcal);
    [in2, ~] = xy_in_calibrated_area([-0.10 -0.20], XYcal);          % 10 cm outside
    [in3, ~] = xy_in_calibrated_area([ 0.02 -0.40], XYcal, 0.03);    % 2 cm outside, inside margin
    [in4, ~] = xy_in_calibrated_area([ NaN  -0.40], XYcal);
    fails = fails + check('xy_in_calibrated_area', in1 && ~in2 && in3 && ~in4, 'ok');

    fprintf('%s\n', repmat('-', 1, 44));
    if fails == 0, fprintf('ALL OFFLINE VLM TESTS PASS\n');
    else, fprintf(2, '%d OFFLINE TEST(S) FAILED\n', fails); end

    %% ===== PART 2: live =================================================
    fprintf('\n===== PART 2: live API (needs a key) =====\n');
    if ~haveKey()
        fprintf('No API key found - skipping. Set GEMINI_API_KEY or create gemini_api_key.txt to run this part.\n\n');
        return
    end
    lfails = 0;
    scene = uint8(110 * ones(480, 640, 3));
    redR = 100:180; redC = 300:400;   bluR = 300:380; bluC = 100:200;
    scene = paint(scene, redR, redC, [220 30 30]);
    scene = paint(scene, bluR, bluC, [30 60 220]);
    after = uint8(110 * ones(480, 640, 3));
    after = paint(after, bluR, bluC, [30 60 220]);
    after = paint(after, 310:370, 120:180, [220 30 30]);   % red now sitting on blue
    figure('Name', 'test_vlm_offline scene'); subplot(1,2,1); imshow(scene); title('before'); subplot(1,2,2); imshow(after); title('after');

    try
        t = tic; [txt, raw] = gemini_generate("Reply with the single word OK.");
        lfails = lfails + check('live text call', contains(upper(txt), 'OK'), ...
            sprintf('"%s" in %.1f s, model %s', strtrim(txt), toc(t), getf(raw, 'modelVersion')));
    catch e
        lfails = lfails + check('live text call', false, e.message);
    end
    try
        t = tic; [uv, items] = vlm_point(scene, "the red square");
        inRed = ~isempty(uv) && uv(1,1) >= redC(1) && uv(1,1) <= redC(end) && uv(1,2) >= redR(1) && uv(1,2) <= redR(end);
        lfails = lfails + check('live vlm_point in red square', inRed, ...
            sprintf('%s "%s" in %.1f s', mat2str(round(uv)), ifelse(isempty(items), '', items(1).label), toc(t)));
    catch e
        lfails = lfails + check('live vlm_point', false, e.message);
    end
    try
        t = tic; plan = vlm_plan(scene, "Put the red square on top of the blue square", ThinkingLevel="medium");
        pOK = plan.pick_uv(1) >= redC(1) && plan.pick_uv(1) <= redC(end) && plan.pick_uv(2) >= redR(1) && plan.pick_uv(2) <= redR(end);
        qOK = plan.place_uv(1) >= bluC(1) && plan.place_uv(1) <= bluC(end) && plan.place_uv(2) >= bluR(1) && plan.place_uv(2) <= bluR(end);
        lfails = lfails + check('live vlm_plan red -> blue', pOK && qOK, ...
            sprintf('pick %s place %s in %.1f s (%s)', mat2str(round(plan.pick_uv)), mat2str(round(plan.place_uv)), toc(t), plan.reason));
    catch e
        lfails = lfails + check('live vlm_plan', false, e.message);
    end
    try
        t = tic; [okV, why] = vlm_verify(scene, after, "Put the red square on top of the blue square", ThinkingLevel="medium");
        lfails = lfails + check('live vlm_verify success', okV, sprintf('%.1f s: %s', toc(t), why));
        [okN, whyN] = vlm_verify(scene, scene, "Put the red square on top of the blue square", ThinkingLevel="medium");
        lfails = lfails + check('live vlm_verify no-change -> false', ~okN, whyN);
    catch e
        lfails = lfails + check('live vlm_verify', false, e.message);
    end
    fprintf('%s\n', repmat('-', 1, 44));
    if lfails == 0, fprintf('ALL LIVE VLM TESTS PASS\n\n');
    else, fprintf(2, '%d LIVE TEST(S) FAILED\n\n', lfails); end
end

function bad = check(name, ok, detail)
    fprintf('%-36s %s  (%s)\n', name, ifelse(ok, 'PASS', '*** FAIL ***'), detail);
    bad = ~ok;
end
function out = ifelse(c, a, b), if c, out = a; else, out = b; end, end
function img = paint(img, rows, cols, rgb)
    for ch = 1:3, img(rows, cols, ch) = rgb(ch); end
end
function v = getf(s, f), if isfield(s, f), v = s.(f); else, v = '?'; end, end
function tf = haveKey()
    tf = strlength(strtrim(string(getenv('GEMINI_API_KEY')))) > 0 || ...
         isfile(fullfile(fileparts(which('gemini_generate')), 'gemini_api_key.txt'));
end
