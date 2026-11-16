function [A, residuals_mm, rms_mm] = fit_pixel_to_base(UV, XY)
%FIT_PIXEL_TO_BASE  Least-squares affine map from image pixels to base XY.
%
%   [A, residuals_mm, rms_mm] = fit_pixel_to_base(UV, XY)
%
%   UV - N x 2 pixel centroids [u v], captured FROM THE IMAGING POSE
%   XY - N x 2 robot base-frame positions [X Y] in meters, from touching
%        the same block positions with the TCP
%   N  - at least 3; use 4 or more so the residuals mean something
%
%   A  - 2 x 3 affine matrix:  [X; Y] = A * [u; v; 1]
%   residuals_mm - per-point fit error (mm); a bad outlier here usually
%        means one row of UV and XY do not describe the same placement
%   rms_mm       - overall fit quality (mm). Under ~3 mm is excellent;
%        above ~5 mm, redo the worst point before trusting picks.
%
%   The map is only valid for blocks on the SAME table plane, seen from
%   the SAME imaging pose used during calibration.

    arguments
        UV (:,2) double
        XY (:,2) double
    end
    n = size(UV,1);
    assert(size(XY,1) == n && n >= 3, ...
        'fit_pixel_to_base:input', 'Need matching UV and XY with at least 3 rows.');

    M = [UV, ones(n,1)];          % n x 3
    A = (M \ XY)';                % 2 x 3 least squares
    pred = M * A';                % n x 2
    err  = XY - pred;             % n x 2, meters
    residuals_mm = sqrt(sum(err.^2, 2)) * 1000;
    rms_mm = sqrt(mean(sum(err.^2, 2))) * 1000;
end
