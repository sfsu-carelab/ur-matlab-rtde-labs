function img = capture_realsense()
%CAPTURE_REALSENSE  Grab one RGB frame from the Intel RealSense camera.
%
%   img = capture_realsense()  ->  H x W x 3 uint8 RGB image
%
%   Requires the RealSense MATLAB wrapper on the path (see the guide
%   "RealSense Set Up With MATLAB" in 1. UR Docs / UR Low-Cost Camera
%   Setup; MATLAB must be started in, or have added, the SDK's matlab
%   folder containing +realsense).
%
%   NOTE FOR INSTRUCTORS: this function follows the wrapper API from the
%   RealSense SOP and the librealsense MATLAB examples. Run it once on
%   the lab PC with the camera attached before class.

    if isempty(which('realsense.pipeline'))
        error('capture_realsense:noWrapper', ...
            ['The RealSense MATLAB wrapper is not on the path. Follow the ' ...
             '"RealSense Set Up With MATLAB" guide, then run MATLAB from the ' ...
             'SDK matlab folder (the one containing +realsense) or addpath it.']);
    end

    pipe = realsense.pipeline();
    cleaner = onCleanup(@() pipe.stop());
    pipe.start();

    % Let auto-exposure settle so colors are stable for thresholding.
    fs = pipe.wait_for_frames();
    for k = 1:15
        fs = pipe.wait_for_frames();
    end

    cf = fs.get_color_frame();
    w  = cf.get_width();
    h  = cf.get_height();
    data = cf.get_data();                              % uint8 vector, RGB interleaved
    img  = permute(reshape(data', [3, w, h]), [3 2 1]); % -> H x W x 3
end
