function [ok, msg] = xy_in_calibrated_area(XYtarget, XYcal, margin_m)
%XY_IN_CALIBRATED_AREA  Refuse targets outside the region you calibrated in Lab 5.
%
%   [ok, msg] = xy_in_calibrated_area(XY, XYcal)            default margin 0.03 m
%   [ok, msg] = xy_in_calibrated_area(XY, XYcal, 0.05)
%
%   XY     - 1 x 2 target [X Y] in metres (base frame)
%   XYcal  - N x 2 calibration points from Lab 5 Table 4
%   margin - how far outside the calibration bounding box is still allowed
%
%   A language model can return a point anywhere in the image, including
%   on the robot itself or off the table. The affine map from Lab 5 is only
%   trustworthy inside (and slightly beyond) the area spanned by the
%   calibration points, so every computed target passes through this check
%   before any motion command.

    arguments
        XYtarget (1,2) double
        XYcal    (:,2) double
        margin_m (1,1) double = 0.03
    end
    lo = min(XYcal, [], 1) - margin_m;
    hi = max(XYcal, [], 1) + margin_m;
    ok = all(XYtarget >= lo & XYtarget <= hi) && all(isfinite(XYtarget));
    if ok
        msg = sprintf('target (%.3f, %.3f) is inside the calibrated area', XYtarget);
    else
        msg = sprintf(['target (%.3f, %.3f) is OUTSIDE the calibrated area ' ...
                       'X [%.3f, %.3f], Y [%.3f, %.3f] (margin %.0f mm) - refusing to move'], ...
                       XYtarget, lo(1), hi(1), lo(2), hi(2), margin_m*1000);
    end
end
