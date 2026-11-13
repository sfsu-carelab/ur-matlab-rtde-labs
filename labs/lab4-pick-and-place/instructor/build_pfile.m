function build_pfile()
%BUILD_PFILE  Rebuild the student copy of the waypoint check as a protected p-file.
%
%   build_pfile()
%
%   INPUT:  none
%   OUTPUT: none returned. Writes ../check_waypoints.p (the file students get).
%
%   Run this after every change to instructor/check_waypoints.m.

    here = fileparts(mfilename('fullpath'));
    pcode(fullfile(here, 'check_waypoints.m'), '-inplace');
    movefile(fullfile(here, 'check_waypoints.p'), fullfile(here, '..', 'check_waypoints.p'), 'f');
    fprintf('wrote %s\n', fullfile(fileparts(here), 'check_waypoints.p'));
end
