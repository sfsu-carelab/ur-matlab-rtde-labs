function UR_FK_Lab(model)
%UR_FK_LAB  Forward kinematics of a UR e-series cobot via screw theory (PoE).
%
%   UR_FK_Lab              runs the lab for the default robot (UR3e)
%   UR_FK_Lab("UR5e")      runs it for any supported UR e-series model
%
%   Supported: UR3e, UR5e, UR7e, UR10e, UR12e, UR16e, UR20, UR30
%
%   Fill in S_list and M in PART 2 below, then run this function.  The
%   self-tests in PART 3 will tell you whether your derivation is correct.
%
%   Required files (keep them all in the same folder): fk_space.m,
%   run_self_tests.m, ur_link_lengths.m, screw2hw.m, hw2screw.m,
%   jointSignConvention.m

    arguments
        model (1,1) string = "UR3e"
    end

    % --- Link lengths for the selected robot (see Table 1 in the manual) ---
    p  = ur_link_lengths(model);
    d1 = p.d1;   % base height           (L1)
    a2 = p.a2;   % upper arm length      (L2)
    a3 = p.a3;   % forearm length        (L3)
    d4 = p.d4;   % wrist-1 lateral offset(L4)
    d5 = p.d5;   % wrist-2 vertical offset(L5)
    d6 = p.d6;   % tool flange offset    (L6)

    fprintf('\n  Robot model: %s\n', p.model);
    fprintf('  d1=%.5f  a2=%.5f  a3=%.5f  d4=%.5f  d5=%.5f  d6=%.5f  (m)\n\n', ...
            d1, a2, a3, d4, d5, d6);

    %% ====================================================================
    %  PART 2 - ENTER YOUR DERIVED PARAMETERS
    %  ====================================================================
    %
    %  TODO: Enter your six screw axes.  Each ROW is S_i = [omega(1:3) v(1:3)].
    %
    %  Write them in terms of d1, a2, a3, d4, d5, d6 - NOT as raw numbers.
    %  Your answer then works for every robot in the family, and you can
    %  re-run this file with a different model to check that it does.
    %
    %  Replace each NaN with your derived expression.
    % ---------------------------------------------------------------------
    S_list = [ ...
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S1  (base)
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S2  (shoulder)
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S3  (elbow)
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S4  (wrist 1)
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S5  (wrist 2)
        NaN, NaN, NaN,   NaN, NaN, NaN;   % S6  (wrist 3)
        ].';   % transpose so each COLUMN is one screw axis

    %  TODO: Enter your home configuration matrix M = [R p; 0 0 0 1].
    % ---------------------------------------------------------------------
    M = [ ...
        NaN, NaN, NaN, NaN; ...
        NaN, NaN, NaN, NaN; ...
        NaN, NaN, NaN, NaN; ...
          0,   0,   0,   1];

    %% ====================================================================
    %  PART 3 - SELF-TESTS   (nothing below this line needs editing)
    %  ====================================================================
    run_self_tests(S_list, M, p);
end
