function genai_hello()
%GENAI_HELLO  Lab 6, Parts 1 and 2: your first generative-AI calls from MATLAB.
%
%   Run this after saving your API key (see gemini_generate help). It makes
%   three calls and prints what goes in, what comes out, and what it cost
%   in tokens:
%     1. text in, text out
%     2. image + question in, text out
%     3. image + question in, JSON out (structured output you can parse)
%
%   Nothing here touches the robot. If a RealSense camera is connected the
%   image is a live frame; otherwise MATLAB's peppers.png is used.

    %% ---- 1. text -> text ---------------------------------------------
    fprintf('\n--- 1. Text prompt ---\n');
    prompt = "In two sentences, what is a collaborative robot and why is it safe to work next to?";
    [reply, raw] = gemini_generate(prompt);
    fprintf('PROMPT : %s\nREPLY  : %s\n', prompt, reply);
    printUsage(raw);

    %% ---- 2. image + question -> text ---------------------------------
    fprintf('\n--- 2. Image question ---\n');
    img = getImage();
    figure(1); clf; imshow(img); title('Image sent to the model');
    prompt = "Describe this image in one sentence, then list the distinct objects you can see.";
    [reply, raw] = gemini_generate(prompt, {img});
    fprintf('PROMPT : %s\nREPLY  : %s\n', prompt, reply);
    printUsage(raw);

    %% ---- 3. image + question -> JSON ---------------------------------
    fprintf('\n--- 3. Structured (JSON) answer ---\n');
    prompt = ['Count the distinct objects in the image. Reply only with JSON of the form ' ...
              '{"count": <integer>, "objects": ["<name>", ...]}'];
    [reply, raw] = gemini_generate(prompt, {img}, JSON=true);
    fprintf('PROMPT : %s\nREPLY  : %s\n', prompt, reply);
    data = vlm_json(reply);               % now it is a MATLAB struct
    fprintf('PARSED : count = %d, objects = %s\n', data.count, strjoin(string(data.objects), ', '));
    printUsage(raw);

    fprintf('\nTASK 1 QUESTION: run this twice. Which replies change between runs, and why\n');
    fprintf('might that matter when the reply is going to drive a robot?\n\n');
end

function img = getImage()
    if ~isempty(which('capture_realsense')) && ~isempty(which('realsense.pipeline'))
        try
            img = capture_realsense();
            fprintf('(live RealSense frame)\n');
            return
        catch e
            fprintf('(camera failed: %s - using peppers.png)\n', e.message);
        end
    end
    img = imread('peppers.png');
    fprintf('(no camera - using MATLAB''s peppers.png)\n');
end

function printUsage(raw)
    if isfield(raw, 'usageMetadata')
        u = raw.usageMetadata;
        fprintf('TOKENS : %d in, %d out, %d total\n', ...
            getf(u, 'promptTokenCount'), getf(u, 'candidatesTokenCount'), getf(u, 'totalTokenCount'));
    end
end

function v = getf(s, f)
    if isfield(s, f), v = s.(f); else, v = 0; end
end
