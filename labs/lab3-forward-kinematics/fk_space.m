function T = fk_space(S_list, M, theta_deg)
%FK_SPACE  Space-frame Product of Exponentials forward kinematics.
%
%   T = fk_space(S_list, M, theta_deg)
%
%   Computes  T = e^{[S1]*theta1} * e^{[S2]*theta2} * ... * e^{[Sn]*thetan} * M
%
%   INPUT:
%     S_list    - 6xN matrix, each COLUMN is one screw axis S_i = [omega; v]
%     M         - 4x4 end-effector pose at the home configuration
%     theta_deg - N joint angles of the screw model (DEGREES), row or column
%
%   OUTPUT:
%     T         - 4x4 end-effector pose in the base frame. T(1:3,1:3) is
%                 the rotation matrix, T(1:3,4) the position (units of M).
%
%   EXAMPLE:
%     T = fk_space(S_list, M, [30 30 -60 30 0 0]);
%     p = T(1:3,4)

    theta = deg2rad(theta_deg);
    T = eye(4);
    for i = 1:size(S_list, 2)
        T = T * twist_exp(S_list(:,i), theta(i));
    end
    T = T * M;
end

function T = twist_exp(S, theta)
%TWIST_EXP  4x4 matrix exponential of one screw axis (Rodrigues' formula).
%   INPUT:  S (6x1 screw axis [omega; v]), theta (angle in radians)
%   OUTPUT: T (4x4 homogeneous transformation)
    omega = S(1:3);
    v     = S(4:6);
    w_hat = skew(omega);
    R = eye(3) + sin(theta)*w_hat + (1 - cos(theta))*(w_hat^2);
    G = eye(3)*theta + (1 - cos(theta))*w_hat + (theta - sin(theta))*(w_hat^2);
    T = [R, G*v; 0 0 0 1];
end

function omega_hat = skew(omega)
%SKEW  3x3 skew-symmetric matrix of a 3x1 vector, so skew(a)*b = cross(a,b).
    omega_hat = [    0,       -omega(3),  omega(2);
                  omega(3),   0,        -omega(1);
                 -omega(2),  omega(1),   0       ];
end
