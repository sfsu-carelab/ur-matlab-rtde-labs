function [ok, diagnostics, text] = vlm_verify(before, after, instruction, opts)
%VLM_VERIFY  Ask the model whether a before/after image pair shows the task was done.
%
%   [ok, why] = vlm_verify(imgBefore, imgAfter, "Put the red block on the blue square")
%
%   ok          - true if the model judges the instruction completed
%   diagnostics - the model's one-paragraph explanation
%   text        - raw reply
%
%   This is the "closing the loop" step: the robot cannot feel whether the
%   grasp worked, but a second picture plus a question can tell you. The
%   caller decides what to do on failure (retry, re-plan, or stop).
%
%   Options: Model, ThinkingLevel ("medium" recommended), CannedResponse.

    arguments
        before
        after
        instruction (1,1) string
        opts.Model          (1,1) string = "gemini-robotics-er-2-preview"
        opts.ThinkingLevel  (1,1) string = ""
        opts.CannedResponse (1,1) string = ""
    end

    prompt = sprintf(['The robot was told: "%s". Image 1 is the table BEFORE the robot ' ...
        'acted and image 2 is AFTER. Decide whether the instruction was completed. ' ...
        'Reply only with JSON: {"success": true or false, "diagnostics": "<what changed, ' ...
        'and what if anything went wrong, in one or two sentences>"}'], instruction);

    if strlength(opts.CannedResponse) > 0
        text = opts.CannedResponse;
    else
        text = gemini_generate(prompt, {"Image 1 (BEFORE):", before, "Image 2 (AFTER):", after}, ...
                               Model=opts.Model, JSON=true, ThinkingLevel=opts.ThinkingLevel);
    end

    d = vlm_json(text);
    ok = false; diagnostics = '';
    if isfield(d, 'success')
        s = d.success;
        if islogical(s) || isnumeric(s), ok = logical(s);
        else, ok = any(strcmpi(string(s), ["true" "yes"])); end
    end
    if isfield(d, 'diagnostics'), diagnostics = char(string(d.diagnostics)); end
end
