function T = fk_space(S_list, M, theta_deg)
% FK_SPACE  Space-frame Product of Exponentials forward kinematics.
%   T = fk_space(S_list, M, theta_deg)
%
%   Computes:  T = e^{[S1]*theta1} * e^{[S2]*theta2} * ... * e^{[S6]*theta6} * M
%
%   Inputs:
%     S_list    — 6xN matrix, each COLUMN is a screw axis S_i
%     M         — 4x4 home configuration
%     theta_deg — Nx1 vector of joint angles (DEGREES)
%
%   Output:
%     T — 4x4 end-effector pose
%
    theta = deg2rad(theta_deg);
    T = eye(4);
    for i = 1:size(S_list, 2)
        T = T * twist_exp(S_list(:,i), theta(i));
    end
    T = T * M;
end

function T = twist_exp(S, theta)
    omega = S(1:3);
    v     = S(4:6);
    w_hat = skew(omega);
    R = eye(3) + sin(theta)*w_hat + (1 - cos(theta))*(w_hat^2);
    G = eye(3)*theta + (1 - cos(theta))*w_hat + (theta - sin(theta))*(w_hat^2);
    T = [R, G*v; 0 0 0 1];
end

function omega_hat = skew(omega)
    omega_hat = [    0,       -omega(3),  omega(2);
                  omega(3),   0,        -omega(1);
                 -omega(2),  omega(1),   0       ];
end
