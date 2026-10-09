function theta_screw = hw2screw(theta_hw, theta_home)
%HW2SCREW  Convert Teach Pendant joint angles to PoE screw-model angles.
%
%   Inverse of SCREW2HW.  All angles in DEGREES.
%
%   See also SCREW2HW, FK_SPACE.

    arguments
        theta_hw   (1,6) double
        theta_home (1,6) double = [0, -90, 0, -90, 0, 0]
    end

    theta_screw = jointSignConvention() .* (theta_hw - theta_home);
end
