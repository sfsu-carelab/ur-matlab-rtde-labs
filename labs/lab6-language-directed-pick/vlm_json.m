function data = vlm_json(text)
%VLM_JSON  Decode a JSON reply from a language model, tolerating markdown fences.
%
%   data = vlm_json(text)
%
%   Models sometimes wrap JSON in ```json ... ``` or add a sentence before
%   it. This strips fences, then falls back to the first [...] or {...}
%   block it can find, and gives a readable error if nothing decodes.

    s = char(string(text));
    s = regexprep(s, '^\s*```[a-zA-Z]*\s*', '');
    s = regexprep(s, '\s*```\s*$', '');
    s = strtrim(s);
    try
        data = jsondecode(s);
        return
    catch
    end
    % fall back: first JSON array or object in the text
    m = regexp(s, '(\[.*\]|\{.*\})', 'match', 'once');
    if isempty(m)
        error('vlm_json:noJSON', 'The model reply contained no JSON:\n%s', s);
    end
    try
        data = jsondecode(m);
    catch e
        error('vlm_json:badJSON', 'Could not decode the model reply (%s):\n%s', e.message, s);
    end
end
