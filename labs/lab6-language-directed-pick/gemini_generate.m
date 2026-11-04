function [text, raw] = gemini_generate(prompt, content, opts)
%GEMINI_GENERATE  One call to the Gemini REST API from plain MATLAB.
%
%   text = gemini_generate("What is a cobot? Answer in one sentence.")
%   text = gemini_generate("How many blocks are on the table?", {img})
%   text = gemini_generate("What changed?", {"BEFORE:", img1, "AFTER:", img2})
%   [text, raw] = gemini_generate(prompt, {img}, Model="gemini-2.5-flash", JSON=true)
%
%   prompt   - the question or instruction (string)
%   content  - optional cell array, in order, of extra parts: an RGB image
%              (H x W x 3 uint8) becomes an inline PNG, a string becomes a
%              text part. Images are sent BEFORE the prompt text.
%   text     - the model's reply with any ```json fences removed
%   raw      - the decoded JSON response (candidates, usageMetadata, ...)
%
%   Uses only webwrite - no Python, no extra toolbox. The API key is taken
%   from the first of:
%     1. the ApiKey=... argument
%     2. the environment variable GEMINI_API_KEY
%        (in MATLAB:  setenv('GEMINI_API_KEY', 'your-key') for this session)
%     3. a one-line file named gemini_api_key.txt in the same folder as
%        this function (never commit or share that file)
%   Get a free key at https://aistudio.google.com/apikey
%
%   Options (name=value)
%     Model          "gemini-robotics-er-2-preview"  (any Gemini model id)
%     SystemPrompt   ""        role / rules the model should follow
%     Temperature    0         0 = deterministic, good for robot commands
%     ThinkingBudget 0         0 = answer immediately (fast pointing);
%                              [] = model default
%     ThinkingLevel  ""        "minimal"|"low"|"medium"|"high" - if set,
%                              used instead of ThinkingBudget
%     JSON           false     true asks for application/json output
%     MaxLongEdge    640       images are shrunk to this before upload
%                              (0 = send full size). Normalized coordinates
%                              the model returns still map to the ORIGINAL.
%     Timeout        90        seconds
%     DryRun         false     true builds the request and returns it as
%                              text without calling the API (for tests)
%
%   REST reference: https://ai.google.dev/api/generate-content
%   Robotics-ER:    https://ai.google.dev/gemini-api/docs/robotics-overview

    arguments
        prompt (1,1) string
        content cell = {}
        opts.Model          (1,1) string  = "gemini-robotics-er-2-preview"
        opts.SystemPrompt   (1,1) string  = ""
        opts.Temperature    (1,1) double  = 0
        opts.ThinkingBudget        double  = 0
        opts.ThinkingLevel  (1,1) string  = ""
        opts.JSON           (1,1) logical = false
        opts.MaxLongEdge    (1,1) double  = 640
        opts.ApiKey         (1,1) string  = ""
        opts.Timeout        (1,1) double  = 90
        opts.DryRun         (1,1) logical = false
    end

    % ---- build the parts list: images / labels first, prompt last ------
    parts = {};
    for k = 1:numel(content)
        c = content{k};
        if isnumeric(c) || islogical(c)
            parts{end+1} = struct('inline_data', struct( ...
                'mime_type', 'image/png', ...
                'data', encodePNG(c, opts.MaxLongEdge))); %#ok<AGROW>
        elseif ischar(c) || isstring(c)
            parts{end+1} = struct('text', char(c)); %#ok<AGROW>
        else
            error('gemini_generate:badContent', ...
                'content{%d} must be an RGB image or a string.', k);
        end
    end
    parts{end+1} = struct('text', char(prompt));

    body.contents = {struct('role', 'user', 'parts', {parts})};

    gc = struct('temperature', opts.Temperature);
    if opts.JSON
        gc.responseMimeType = 'application/json';
    end
    if strlength(opts.ThinkingLevel) > 0
        gc.thinkingConfig = struct('thinkingLevel', char(opts.ThinkingLevel));
    elseif ~isempty(opts.ThinkingBudget)
        gc.thinkingConfig = struct('thinkingBudget', opts.ThinkingBudget);
    end
    body.generationConfig = gc;

    if strlength(opts.SystemPrompt) > 0
        body.systemInstruction = struct('parts', {{struct('text', char(opts.SystemPrompt))}});
    end

    bodyJSON = jsonencode(body);

    if opts.DryRun
        text = string(bodyJSON);
        raw  = body;
        return
    end

    % ---- call the API ---------------------------------------------------
    key = resolveApiKey(opts.ApiKey);
    url = sprintf('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent', opts.Model);
    wo  = weboptions('MediaType', 'application/json', 'ContentType', 'json', ...
                     'HeaderFields', {'x-goog-api-key', char(key)}, ...
                     'Timeout', opts.Timeout, 'RequestMethod', 'post');
    try
        raw = webwrite(url, bodyJSON, wo);
    catch e
        error('gemini_generate:http', '%s\n  %s', e.message, hintFor(e.message, opts.Model));
    end

    % ---- pull the reply text out ----------------------------------------
    if isfield(raw, 'promptFeedback') && isfield(raw.promptFeedback, 'blockReason')
        error('gemini_generate:blocked', 'Request blocked: %s', raw.promptFeedback.blockReason);
    end
    if ~isfield(raw, 'candidates') || isempty(raw.candidates)
        error('gemini_generate:empty', 'No candidates in the response:\n%s', jsonencode(raw));
    end
    cand = raw.candidates(1);
    if iscell(cand), cand = cand{1}; end
    text = "";
    if isfield(cand, 'content') && isfield(cand.content, 'parts')
        ps = cand.content.parts;
        if isstruct(ps), ps = num2cell(ps); end
        for k = 1:numel(ps)
            p = ps{k};
            if isfield(p, 'thought') && p.thought, continue; end   % skip thinking
            if isfield(p, 'text'), text = text + string(p.text); end
        end
    end
    if isfield(cand, 'finishReason') && ~strcmp(cand.finishReason, 'STOP')
        warning('gemini_generate:finish', 'finishReason = %s', cand.finishReason);
    end
    text = stripFences(text);
end

% -------------------------------------------------------------------------
function b64 = encodePNG(img, maxLongEdge)
    if ~isa(img, 'uint8')
        if isfloat(img) && max(img(:)) <= 1, img = uint8(255 * img);
        else, img = uint8(img); end
    end
    if maxLongEdge > 0 && max(size(img, 1), size(img, 2)) > maxLongEdge && ~isempty(which('imresize'))
        img = imresize(img, maxLongEdge / max(size(img, 1), size(img, 2)));
    end
    tmp = [tempname '.png'];
    imwrite(img, tmp);
    fid = fopen(tmp, 'r'); bytes = fread(fid, inf, '*uint8'); fclose(fid);
    delete(tmp);
    b64 = matlab.net.base64encode(bytes);
end

function key = resolveApiKey(given)
    key = strtrim(string(given));
    if strlength(key) > 0, return; end
    key = strtrim(string(getenv('GEMINI_API_KEY')));
    if strlength(key) > 0, return; end
    f = fullfile(fileparts(mfilename('fullpath')), 'gemini_api_key.txt');
    if isfile(f)
        key = strtrim(string(fileread(f)));
        if strlength(key) > 0, return; end
    end
    error('gemini_generate:noKey', ['No Gemini API key found. Either run\n' ...
        '    setenv(''GEMINI_API_KEY'', ''your-key'')\n' ...
        'in MATLAB, or save the key as the only line of\n    %s\n' ...
        'Create a key at https://aistudio.google.com/apikey'], f);
end

function s = stripFences(s)
    s = regexprep(s, '^\s*```[a-zA-Z]*\s*', '');
    s = regexprep(s, '\s*```\s*$', '');
    s = strtrim(s);
end

function h = hintFor(msg, model)
    if contains(msg, '400')
        h = 'HTTP 400: the request body was rejected - usually an unsupported generationConfig field for this model (try ThinkingLevel="low" instead of ThinkingBudget, or vice versa).';
    elseif contains(msg, '401') || contains(msg, '403')
        h = 'HTTP 401/403: the API key is missing, invalid, or unrestricted (AI Studio keys must be restricted to the Generative Language API).';
    elseif contains(msg, '404')
        h = sprintf('HTTP 404: model "%s" not found. Check the current id at https://ai.google.dev/gemini-api/docs/models', model);
    elseif contains(msg, '429')
        h = 'HTTP 429: rate limit or daily quota - wait a minute, or use a different model/key.';
    elseif contains(msg, 'Timeout') || contains(msg, 'timed out')
        h = 'Timed out: check internet access on this PC (a robot-only Ethernet link has none - use Wi-Fi as well).';
    else
        h = 'Check internet access and the API key.';
    end
end
