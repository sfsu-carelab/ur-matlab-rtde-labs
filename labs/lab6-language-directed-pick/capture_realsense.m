function img = capture_realsense()
%CAPTURE_REALSENSE  Grab one RGB frame from the Intel RealSense camera.
%
%   img = capture_realsense()  ->  H x W x 3 uint8 RGB image
%
%   Uses the "MATLAB Support Package for USB Webcams" (Add-Ons > Get
%   Hardware Support Packages; installs to your user folder, no admin
%   rights needed). The RealSense RGB sensor is a standard UVC camera, so
%   the Intel RealSense SDK is NOT required. These labs use color only;
%   the depth stream is not read.
%
%   The resolution is pinned to 1280x720 when the camera offers it, so the
%   pixel-to-base calibration from Part 4 stays valid between sessions.
%
%   2026-11-04: changed from the RealSense SDK MATLAB wrapper to the USB
%   Webcams package because the lab PCs have no admin rights for the SDK
%   installer (Ryan's decision, see the hardware-validation notes).

    if isempty(which('webcam'))
        error('capture_realsense:noPackage', ...
            ['The USB Webcams support package is not installed. In MATLAB go to ' ...
             'Add-Ons > Get Hardware Support Packages and install ' ...
             '"MATLAB Support Package for USB Webcams" (Lab 5, Part 1).']);
    end

    names = webcamlist;
    k = find(contains(names, 'RealSense', 'IgnoreCase', true) & ...
             contains(names, 'RGB',       'IgnoreCase', true), 1);
    if isempty(k), k = find(contains(names, 'RealSense', 'IgnoreCase', true), 1); end
    if isempty(k)
        error('capture_realsense:noCamera', ...
            ['No RealSense camera found. Check the USB cable, then run webcamlist. ' ...
             'It returned: %s'], strjoin(names, ', '));
    end

    cam = webcam(names{k});
    if any(strcmp(cam.AvailableResolutions, '1280x720'))
        cam.Resolution = '1280x720';
    end

    % Let auto-exposure settle so colors are stable for thresholding.
    % 2026-11-04 hardware: the D435i RGB auto-exposure needs about 25-30 frames (1.5 s) to
    % settle; at frame 15 the image was still only half as bright as at frame 30.
    for n = 1:30
        img = snapshot(cam);
    end
    clear cam                                          % release the camera
end
