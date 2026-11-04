function plan = vlm_plan(img, instruction, opts)
%VLM_PLAN  Turn a natural-language instruction into a pick point and a place point.
%
%   plan = vlm_plan(img, "Put the red block on the blue square")
%
%   plan.pick_uv     [u v] pixel of the object to pick (center of its top face)
%   plan.place_uv    [u v] pixel of where to put it down
%   plan.pick_label  what the model thinks it is picking
%   plan.place_label what the model thinks the destination is
%   plan.reason      one sentence from the model
%   plan.text        raw reply
%
%   The model only sees the image and the sentence. It does not know
%   where the robot is, so everything it returns must still pass through
%   your Lab 5 calibration (pixel_to_base) and a workspace bounds check
%   before the robot moves.
%
%   Options: Model, ThinkingLevel ("medium" is a good default for
%   planning), CannedResponse (offline tests).

    arguments
        img
        instruction (1,1) string
        opts.Model          (1,1) string = "gemini-robotics-er-2-preview"
        opts.ThinkingLevel  (1,1) string = ""
        opts.CannedResponse (1,1) string = ""
    end

    sys = ['You are guiding a robot arm. A camera on the robot looks straight down ' ...
           'at a table. You answer only with JSON, no prose, no markdown.'];
    prompt = sprintf(['Instruction for the robot: "%s"\n' ...
        'Identify the object to pick up and the location where it should be put down. ' ...
        'Reply with exactly this JSON object: ' ...
        '{"pick": {"point": [y, x], "label": "<object>"}, ' ...
        '"place": {"point": [y, x], "label": "<destination>"}, ' ...
        '"reason": "<one sentence>"}. ' ...
        'Points are [y, x] normalized to 0-1000. The pick point is the center of the ' ...
        'top face of the object. The place point is a free spot at the destination ' ...
        'where the object will not collide with anything, unless the instruction ' ...
        'asks to stack. If the instruction cannot be carried out, set both points to null ' ...
        'and explain in "reason".'], instruction);

    if strlength(opts.CannedResponse) > 0
        text = opts.CannedResponse;
    else
        text = gemini_generate(prompt, {img}, Model=opts.Model, SystemPrompt=sys, ...
                               JSON=true, ThinkingLevel=opts.ThinkingLevel);
    end

    d = vlm_json(text);
    H = size(img,1); W = size(img,2);
    plan = struct('pick_uv', [NaN NaN], 'place_uv', [NaN NaN], ...
                  'pick_label', '', 'place_label', '', 'reason', '', 'text', char(text));
    if isfield(d, 'reason'), plan.reason = char(string(d.reason)); end
    [plan.pick_uv,  plan.pick_label]  = one(d, 'pick',  W, H);
    [plan.place_uv, plan.place_label] = one(d, 'place', W, H);
end

function [uv, lbl] = one(d, name, W, H)
    uv = [NaN NaN]; lbl = '';
    if ~isfield(d, name) || ~isstruct(d.(name)), return; end
    s = d.(name);
    if isfield(s, 'label'), lbl = char(string(s.label)); end
    if isfield(s, 'point') && isnumeric(s.point) && numel(s.point) == 2
        yx = double(s.point(:)');
        uv = [yx(2) / 1000 * W, yx(1) / 1000 * H];
    end
end
