function theta_screw = hw2screw(theta_hw, theta_home)
%HW2SCREW  Convert Teach Pendant joint angles to screw-model joint angles.
%
%   theta_screw = hw2screw(theta_hw)
%   theta_screw = hw2screw(theta_hw, theta_home)
%
%   INPUT:
%     theta_hw    - 1x6 joint angles as the Teach Pendant shows them (DEGREES)
%     theta_home  - 1x6 Teach Pendant reading at the upright home
%                   configuration of Figure 1 (DEGREES).
%                   Default [0, -90, 0, -90, 0, 0]
%
%   OUTPUT:
%     theta_screw - 1x6 joint angles of the screw model (DEGREES), the
%                   angles that fk_space expects
%
%   Inverse of SCREW2HW:   theta_screw = theta_hw - theta_home
%
%   EXAMPLE:
%     hw2screw([30 -60 -60 -60 0 0])    returns [30 30 -60 30 0 0]
%
%   See also SCREW2HW, FK_SPACE.

    arguments
        theta_hw   (1,6) double
        theta_home (1,6) double = [0, -90, 0, -90, 0, 0]
    end

    theta_screw = theta_hw - theta_home;
end
