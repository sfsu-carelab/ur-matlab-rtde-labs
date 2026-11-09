function theta_hw = screw2hw(theta_screw, theta_home)
%SCREW2HW  Convert screw-model joint angles to Teach Pendant joint angles.
%
%   theta_hw = screw2hw(theta_screw)
%   theta_hw = screw2hw(theta_screw, theta_home)
%
%   INPUT:
%     theta_screw - 1x6 joint angles of the screw model (DEGREES), measured
%                   from the upright home configuration of Figure 1
%     theta_home  - 1x6 Teach Pendant reading at that upright home
%                   configuration (DEGREES). Default [0, -90, 0, -90, 0, 0]
%
%   OUTPUT:
%     theta_hw    - 1x6 joint angles as the Teach Pendant shows them (DEGREES)
%
%   The screw axes in this lab point the same way the robot counts positive
%   rotation, so the two sets of angles differ only by where zero is:
%
%       theta_hw = theta_screw + theta_home
%
%   EXAMPLE:
%     screw2hw([30 30 -60 30 0 0])      returns [30 -60 -60 -60 0 0]
%
%   See also HW2SCREW, FK_SPACE.

    arguments
        theta_screw (1,6) double
        theta_home  (1,6) double = [0, -90, 0, -90, 0, 0]
    end

    theta_hw = theta_screw + theta_home;
end
