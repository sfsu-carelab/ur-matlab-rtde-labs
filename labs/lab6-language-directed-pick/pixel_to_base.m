function XY = pixel_to_base(A, uv)
%PIXEL_TO_BASE  Apply the calibrated affine map to one pixel centroid.
%
%   XY = pixel_to_base(A, uv)  ->  [X Y] in meters (robot base frame)
%
%   A  - 2 x 3 matrix from fit_pixel_to_base
%   uv - [u v] pixel centroid from detect_block

    arguments
        A  (2,3) double
        uv (1,2) double
    end
    XY = (A * [uv(1); uv(2); 1])';
end
