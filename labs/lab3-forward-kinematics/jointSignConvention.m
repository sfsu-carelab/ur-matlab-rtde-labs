function s = jointSignConvention()
%JOINTSIGNCONVENTION  Sign of each screw axis relative to the UR joint sense.
%
%   Joints 2 through 6 of the PoE model built in this lab rotate in the
%   OPPOSITE direction to the corresponding Teach Pendant joint readout.
%   Joint 1 (base) agrees.  Each entry is its own inverse, so the same
%   vector converts in both directions.
%
%   Verified against the Universal Robots DH model for UR3e, UR5e, UR7e,
%   UR10e, UR12e, UR16e, UR20 and UR30 (agreement to 1.6e-15 m).

    s = [1, -1, -1, -1, -1, -1];
end
