function theta_hw = screw2hw(theta_screw, theta_home)
%SCREW2HW  Convert PoE screw-model joint angles to Teach Pendant angles.
%
%   theta_hw = screw2hw(theta_screw)
%   theta_hw = screw2hw(theta_screw, theta_home)
%
%   The PoE model in this lab measures every joint angle from the UPRIGHT
%   home configuration, using the screw axes you derived.  The Teach Pendant
%   measures joint angles from UR's own zero (arm stretched horizontally) and
%   its positive sense is OPPOSITE to the lab's screw axes on joints 2-6.
%
%   The full conversion is therefore a sign flip AND an offset:
%
%       theta_hw(i) = SIGN(i) * theta_screw(i) + theta_home(i)
%
%   with SIGN = [+1, -1, -1, -1, -1, -1].  A pure addition is NOT correct.
%
%   theta_home defaults to [0, -90, 0, -90, 0, 0] deg, which is where the
%   pendant reads when the arm is at the upright Smart Skills "Home" pose.
%   Record your own robot's values in Task 3 and pass them in if they differ.
%
%   All angles are in DEGREES.
%
%   See also HW2SCREW, FK_SPACE.

    arguments
        theta_screw (1,6) double
        theta_home  (1,6) double = [0, -90, 0, -90, 0, 0]
    end

    theta_hw = jointSignConvention() .* theta_screw + theta_home;
end
