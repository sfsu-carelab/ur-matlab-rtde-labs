function UR_FK_Lab(model)
%UR_FK_LAB  Forward kinematics of a UR e-series cobot via screw theory (PoE).
%
%   UR_FK_Lab(model)
%
%   INPUT:
%     model - string with the robot model. Supported:
%             "UR3e"  "UR5e"  "UR7e"  "UR10e"  "UR12e"  "UR16e"  "UR20"  "UR30"
%             (default "UR3e")
%
%   OUTPUT:
%     None returned. The self-test results are printed in the Command
%     Window, and S_list (6x6, one screw axis per column) and M (4x4 home
%     pose) are saved to the base workspace for use in Part 4.
%
%   EXAMPLE:
%     UR_FK_Lab              runs the lab for the default robot (UR3e)
%     UR_FK_Lab("UR5e")      runs it for any supported model
%
%   USER INSTRUCTION:
%     Fill in S_list and M in PART 2 below, then run this function. The
%     self-tests in PART 3 tell you whether your derivation is correct.
%
%   Required files (keep them all in the same folder): fk_space.m,
%   run_self_tests.p, ur_link_lengths.m, screw2hw.m, hw2screw.m

    arguments
        model (1,1) string = "UR3e"
    end

    % --- Link lengths for the selected robot (Figure 1 and Table 1 in the manual) ---
    p  = ur_link_lengths(model);
    L1 = p.L1;   % base to shoulder (joint 2) height
    L2 = p.L2;   % upper arm length, joint 2 to joint 3
    L3 = p.L3;   % forearm length, joint 3 to joint 4
    L4 = p.L4;   % sideways offset of the joint 5 axis
    L5 = p.L5;   % height of joint 6 above joint 4
    L6 = p.L6;   % joint 5 axis to the tool flange

    fprintf('\n  Robot model: %s\n', p.model);
    fprintf('  L1=%.5f  L2=%.5f  L3=%.5f  L4=%.5f  L5=%.5f  L6=%.5f  (m)\n\n', ...
            L1, L2, L3, L4, L5, L6);

    %% ====================================================================
    %  PART 2 - ENTER YOUR DERIVED PARAMETERS
    %  ====================================================================
    %
    %  TODO: Enter your six screw axes.  Each ROW is S_i = [omega(1:3) v(1:3)].
    %
    %  Write them in terms of L1, L2, L3, L4, L5, L6 - NOT as raw numbers.
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
