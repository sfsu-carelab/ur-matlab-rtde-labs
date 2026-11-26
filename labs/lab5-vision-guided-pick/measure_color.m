function c = measure_color()
%MEASURE_COLOR  Click on the block and on the table to read their HSV colors.
%
%   measure_color          takes one picture, then asks for two clicks
%   c = measure_color()    also returns the result
%
%   INPUT:  none
%   OUTPUT: c - 2 x 3 matrix. Row 1 is [h s v] of the block, row 2 is [h s v]
%           of the table, each on a scale from 0 to 1.
%
%   Used in Lab 5, Task 3, to choose hsvLow and hsvHigh. Each click is
%   averaged over a 5 x 5 pixel patch, so one odd pixel does not matter.
%   The average is taken in RGB and then converted, which keeps a red hue
%   (close to 0 or to 1) from averaging to a wrong color.
%
%   This function only uses the camera. It does not connect to the robot.

    img = capture_realsense();
    figure(1); clf; imshow(img);
    names = {'block', 'table'};
    c = nan(2, 3);
    for k = 1:2
        if k == 1
            title('Click on a plain, evenly colored spot on TOP of the block');
        else
            title('Now click on the bare TABLE next to the block');
        end
        [x, y] = ginput(1);
        col = min(max(round(x), 3), size(img, 2) - 2);     % keep the patch inside the picture
        row = min(max(round(y), 3), size(img, 1) - 2);
        patch = double(img(row-2:row+2, col-2:col+2, :)) / 255;
        rgb = reshape(mean(mean(patch, 1), 2), 1, 3);
        c(k, :) = rgb2hsv(rgb);
        fprintf('  %s:  h = %.2f   s = %.2f   v = %.2f\n', names{k}, c(k, 1), c(k, 2), c(k, 3));
    end
    title('Done. Copy the two lines from the Command Window into Table 3');
    if nargout == 0
        clear c
    end
end
