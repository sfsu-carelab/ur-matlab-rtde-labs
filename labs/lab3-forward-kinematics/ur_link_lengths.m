function p = ur_link_lengths(model)
%UR_LINK_LENGTHS  Link lengths L1 to L6 of a UR e-series manipulator.
%
%   p = ur_link_lengths(model)
%
%   INPUT:
%     model - string with the robot model. Supported:
%             "UR3e"  "UR5e"  "UR7e"  "UR10e"  "UR12e"  "UR16e"  "UR20"  "UR30"
%             (default "UR3e")
%
%   OUTPUT:
%     p     - struct with the fields model, L1, L2, L3, L4, L5, L6.
%             L1 to L6 are the link lengths of Figure 1 in the lab manual
%             (units in meters).
%
%   EXAMPLE:
%     p = ur_link_lengths("UR5e");
%     disp(p.L2)
%
%   Source: Universal Robots, "DH Parameters for calculations of kinematics
%   and dynamics", https://www.universal-robots.com/articles/ur/
%   application-installation/dh-parameters-for-calculations-of-kinematics-
%   and-dynamics/
%   That table names the same six lengths d1, a2, a3, d4, d5, d6 (and lists
%   a2 and a3 as negative). This lab uses screw theory, which only needs
%   the magnitudes, so they are simply numbered L1 to L6 from the base up.

    arguments
        model (1,1) string = "UR3e"
    end

    %          L1        L2        L3        L4        L5        L6
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
               'L1', T{idx,2}, 'L2', T{idx,3}, 'L3', T{idx,4}, ...
               'L4', T{idx,5}, 'L5', T{idx,6}, 'L6', T{idx,7});
end
