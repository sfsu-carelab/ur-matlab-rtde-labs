function [uv, items, text] = vlm_point(img, what, opts)
%VLM_POINT  Ask a vision-language model to point at an object in an image.
%
%   uv = vlm_point(img, "the red block")
%   [uv, items, text] = vlm_point(img, "each colored block", MaxItems=5)
%
%   img   - RGB image (H x W x 3 uint8), e.g. from capture_realsense
%   what  - plain-English description of what to point at
%   uv    - N x 2 pixel coordinates [u v] (column, row) of the points the
%           model returned, in the ORIGINAL image size. Empty if none.
%   items - struct array with fields label, point_norm ([y x] 0-1000), uv
%   text  - the raw model reply, for debugging
%
%   This replaces detect_block from Lab 5: instead of tuning HSV
%   thresholds you describe the object in words. The model answers with
%   points normalized to 0-1000 in [y, x] order (the Gemini Robotics-ER
%   convention), which this function converts to pixels.
%
%   Options: Model (default gemini-robotics-er-2-preview), MaxItems (1),
%   ThinkingLevel (""), CannedResponse ("" - for offline tests).

    arguments
        img
        what (1,1) string
        opts.Model          (1,1) string = "gemini-robotics-er-2-preview"
        opts.MaxItems       (1,1) double = 1
        opts.ThinkingLevel  (1,1) string = ""
        opts.CannedResponse (1,1) string = ""
    end

    prompt = sprintf(['Point to %s in the image. Return at most %d item(s). ' ...
        'The label returned should be an identifying name for the object detected. ' ...
        'The answer should follow the json format: [{"point": <point>, "label": <label1>}, ...]. ' ...
        'The points are in [y, x] format normalized to 0-1000. ' ...
        'If nothing matches, return an empty list [].'], what, round(opts.MaxItems));

    if strlength(opts.CannedResponse) > 0
        text = opts.CannedResponse;
    else
        text = gemini_generate(prompt, {img}, Model=opts.Model, JSON=true, ...
                               ThinkingLevel=opts.ThinkingLevel);
    end

    [uv, items] = vlm_parse_points(text, size(img));
end

% -------------------------------------------------------------------------
function [uv, items] = vlm_parse_points(text, imSize)
    H = imSize(1); W = imSize(2);
    data = vlm_json(text);
    items = struct('label', {}, 'point_norm', {}, 'uv', {});
    if isempty(data), uv = zeros(0,2); return; end
    if isstruct(data), data = num2cell(data); end
    if ~iscell(data), data = {data}; end
    for k = 1:numel(data)
        d = data{k};
        if ~isstruct(d) || ~isfield(d, 'point') || numel(d.point) ~= 2, continue; end
        yx = double(d.point(:)');
        u  = yx(2) / 1000 * W;
        v  = yx(1) / 1000 * H;
        lbl = '';
        if isfield(d, 'label'), lbl = char(string(d.label)); end
        items(end+1) = struct('label', lbl, 'point_norm', yx, 'uv', [u v]); %#ok<AGROW>
    end
    if isempty(items), uv = zeros(0,2); else, uv = vertcat(items.uv); end
end
