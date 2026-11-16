function [uv, mask, stats] = detect_block(img, hsvLow, hsvHigh, minAreaPx)
%DETECT_BLOCK  Find the largest colored blob in an RGB image.
%
%   [uv, mask, stats] = detect_block(img, hsvLow, hsvHigh, minAreaPx)
%
%   img       - RGB image (uint8 or double)
%   hsvLow    - [h s v] lower thresholds, each in 0..1
%   hsvHigh   - [h s v] upper thresholds, each in 0..1
%   minAreaPx - blobs smaller than this many pixels are ignored
%
%   uv    - [u v] centroid of the largest blob, in pixels ([NaN NaN] if
%           nothing passed the threshold - always check before using it)
%   mask  - the binary threshold image, for tuning
%   stats - regionprops output for all surviving blobs
%
%   Hue wraps around at red: if hsvLow(1) > hsvHigh(1) the hue band is
%   taken as [hsvLow(1), 1] plus [0, hsvHigh(1)], so red is selected with
%   e.g. hsvLow = [0.95 0.5 0.3], hsvHigh = [0.05 1.0 1.0].
%
%   Requires the Image Processing Toolbox (bwareaopen, regionprops).

    arguments
        img
        hsvLow  (1,3) double
        hsvHigh (1,3) double
        minAreaPx (1,1) double = 200
    end

    hsv = rgb2hsv(img);
    h = hsv(:,:,1); s = hsv(:,:,2); v = hsv(:,:,3);

    if hsvLow(1) <= hsvHigh(1)
        hm = h >= hsvLow(1) & h <= hsvHigh(1);
    else                                   % wrap-around band (reds)
        hm = h >= hsvLow(1) | h <= hsvHigh(1);
    end
    mask = hm & s >= hsvLow(2) & s <= hsvHigh(2) ...
              & v >= hsvLow(3) & v <= hsvHigh(3);
    mask = bwareaopen(mask, round(minAreaPx));

    stats = regionprops(mask, 'Centroid', 'Area');
    if isempty(stats)
        uv = [NaN NaN];
        return
    end
    [~, k] = max([stats.Area]);
    uv = stats(k).Centroid;
end
