function p = ur_link_lengths(model)
%UR_LINK_LENGTHS  Kinematic link lengths for any UR e-series manipulator.
%
%   p = ur_link_lengths(model) returns a struct with fields d1, a2, a3,
%   d4, d5, d6 (all in metres) for the requested robot.
%
%   Supported models:
%     "UR3e"   "UR5e"   "UR7e"   "UR10e"   "UR12e"   "UR16e"   "UR20"   "UR30"
%
%   Values are the magnitudes of the offsets in the DH table published by
%   Universal Robots (UR lists a2 and a3 as negative; this lab uses the
%   Product-of-Exponentials convention, which needs the magnitudes).
%
%   Source: Universal Robots, "DH Parameters for calculations of kinematics
%   and dynamics", https://www.universal-robots.com/articles/ur/
%   application-installation/dh-parameters-for-calculations-of-kinematics-
%   and-dynamics/
%
%   Example:
%       p = ur_link_lengths("UR5e");
%       disp(p.a2)

    arguments
        model (1,1) string = "UR3e"
    end

    %          d1        a2        a3        d4        d5        d6
    T = { ...
      "UR3e" , 0.15185 , 0.24355 , 0.21320 , 0.13105 , 0.08535 , 0.09210 ; ...
      "UR5e" , 0.16250 , 0.42500 , 0.39220 , 0.13330 , 0.09970 , 0.09960 ; ...
      "UR7e" , 0.16250 , 0.42500 , 0.39220 , 0.13330 , 0.09970 , 0.09960 ; ...
      "UR10e", 0.18070 , 0.61270 , 0.57155 , 0.17415 , 0.11985 , 0.11655 ; ...
      "UR12e", 0.18070 , 0.61270 , 0.57155 , 0.17415 , 0.11985 , 0.11655 ; ...
      "UR16e", 0.18070 , 0.47840 , 0.36000 , 0.17415 , 0.11985 , 0.11655 ; ...
      "UR20" , 0.23630 , 0.86200 , 0.72870 , 0.20100 , 0.15930 , 0.15430 ; ...
      "UR30" , 0.23630 , 0.63700 , 0.50370 , 0.20100 , 0.15930 , 0.15430 };

    names = string(T(:,1));
    idx = find(strcmpi(names, model), 1);
    if isempty(idx)
        error("ur_link_lengths:unknownModel", ...
              "Unknown model '%s'. Supported: %s.", model, strjoin(names, ", "));
    end

    p = struct('model', names(idx), ...
               'd1', T{idx,2}, 'a2', T{idx,3}, 'a3', T{idx,4}, ...
               'd4', T{idx,5}, 'd5', T{idx,6}, 'd6', T{idx,7});
end
