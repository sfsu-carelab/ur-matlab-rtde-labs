function make_lab3_figure1(outPng)
%MAKE_LAB3_FIGURE1  Draw the Lab 3 schematic: UR3e side view in the lab's own
%   convention (base frame lettered, joints numbered, omega_i arrows as the
%   lab uses them, link lengths dimensioned).  Horizontal axis of the drawing
%   is -y (so +y points LEFT, toward the cable), vertical is +z, +x is INTO
%   the page.

L1 = 0.15185; L2 = 0.24355; L3 = 0.21320; L4 = 0.13105; L5 = 0.08535; L6 = 0.09210;
h2 = L1; h3 = L1+L2; h4 = L1+L2+L3; h6 = h4+L5; u5 = L4; uF = L4+L6;

fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 6.4 8.6], 'Visible', 'off');
ax = axes(fig, 'Position', [0.02 0.02 0.96 0.96]); hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
xlim(ax, [-0.38 0.54]); ylim(ax, [-0.27 0.90]);

grey = [0.55 0.55 0.55]; blue = [0 0.35 0.8]; red = [0.8 0.1 0.1]; green = [0 0.55 0.15];
lw = 9;

% --- base pedestal and the joint 1 axis
patch(ax, [-0.06 0.06 0.06 -0.06], [-0.04 -0.04 0 0], [0.85 0.85 0.85], 'EdgeColor', 'k');
plot(ax, [0 0], [-0.06 0.80], 'k--', 'LineWidth', 0.6);
text(ax, 0.012, 0.79, 'joint 1 axis', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);

% --- arm (model geometry: joints 2,3,4 on the base axis; wrist offset to -y)
plot(ax, [0 0], [0 h4], '-', 'Color', grey, 'LineWidth', lw);
plot(ax, [0 u5], [h4 h4], '-', 'Color', grey, 'LineWidth', lw);
plot(ax, [u5 u5], [h4 h6], '-', 'Color', grey, 'LineWidth', lw);
plot(ax, [u5 uF], [h6 h6], '-', 'Color', grey, 'LineWidth', lw);
plot(ax, [u5 u5], [h4-0.05 h6+0.05], 'k--', 'LineWidth', 0.6);     % joint 5 axis
text(ax, u5+0.012, h4-0.045, 'joint 5 axis', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
% flange plate
patch(ax, uF+[0 0.012 0.012 0], h6+[-0.03 -0.03 0.03 0.03], [0.3 0.3 0.3], 'EdgeColor', 'k');

% --- joint points and numbers
J = [0 0; 0 h2; 0 h3; 0 h4; u5 h4; u5 h6];
for i = 1:6
    plot(ax, J(i,1), J(i,2), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 7, 'LineWidth', 1.2);
end
num = @(u, z, s) text(ax, u, z, s, 'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 2);
num(0.075, 0.035, '1'); num(0.075, h2, '2'); num(0.075, h3, '3'); num(-0.075, h4-0.04, '4');
num(u5-0.045, h4+0.045, '5'); num(u5-0.045, h6+0.045, '6');

% --- omega arrows (the lab's convention)
arrow(ax, [0 0], [0.02 0.11], red, 2);  tx(ax, 0.015, 0.06, '\omega_1 = +z', red);
for z = [h2 h3 h4]
    arrow(ax, [0 -0.085], [z z], red, 2);
end
tx(ax, -0.36, h2+0.022, '\omega_2 = +y', red);
tx(ax, -0.36, h3+0.022, '\omega_3 = +y', red);
tx(ax, -0.36, h4+0.022, '\omega_4 = +y', red);
arrow(ax, [u5 u5], [h4 h4-0.085], red, 2); tx(ax, u5+0.015, h4-0.09, '\omega_5 = -z', red);
arrow(ax, [u5 u5-0.085], [h6 h6], red, 2); tx(ax, u5-0.22, h6+0.03, '\omega_6 = +y', red);

% --- base frame (bottom left)
ob = [-0.26 -0.10];
arrow(ax, [ob(1) ob(1)-0.085], [ob(2) ob(2)], green, 1.5); tx(ax, ob(1)-0.12, ob(2)+0.022, '+y', green);
arrow(ax, [ob(1) ob(1)], [ob(2) ob(2)+0.085], blue, 1.5);  tx(ax, ob(1)+0.012, ob(2)+0.08, '+z', blue);
circ(ax, ob, 0.011, 'x');  tx(ax, ob(1)+0.018, ob(2)-0.03, '+x (into page)', [0 0 0]);
text(ax, ob(1)-0.11, ob(2)-0.07, 'base frame {s}', 'FontSize', 9, 'FontWeight', 'bold');

% --- tool frame at the flange
of = [uF+0.012 h6];
arrow(ax, [of(1) of(1)+0.075], [of(2) of(2)], blue, 1.5);  tx(ax, of(1)+0.03, of(2)+0.022, 'z_{tool}', blue);
arrow(ax, [of(1) of(1)], [of(2) of(2)-0.075], green, 1.5); tx(ax, of(1)+0.012, of(2)-0.075, 'y_{tool}', green);
circ(ax, of, 0.011, 'o');  tx(ax, of(1)+0.018, of(2)+0.06, 'x_{tool} (out of page)', [0 0 0]);
text(ax, of(1)-0.10, of(2)+0.13, 'tool frame {b} at home', 'FontSize', 9, 'FontWeight', 'bold');

% --- dimensions
dimv(ax, -0.14, 0, h2, 'L_1 (d1)');
dimv(ax, -0.14, h2, h3, 'L_2 (a2)');
dimv(ax, -0.14, h3, h4, 'L_3 (a3)');
dimh(ax, h4-0.19, 0, u5, 'L_4 (d4)');
dimv(ax, u5+0.24, h4, h6, 'L_5 (d5)');
dimh(ax, h6+0.08, u5, uF, 'L_6 (d6)');

% --- legend box
txt = {'Red arrows: the positive rotation direction \omega_i of each joint as used in THIS', ...
       'lab (right-hand rule about the arrow). The teach pendant counts joints 2 to 6', ...
       'the OPPOSITE way; Part 4 converts between the two. The joint 2, 3, 4 and 6 axes', ...
       'are drawn where they cross the side view: their real sideways offset (along x)', ...
       'is parallel to \omega and therefore does not change v. Joint 6 sits L4 out at -y.'};
text(ax, -0.37, -0.265, txt, 'FontSize', 7.5, 'VerticalAlignment', 'bottom', ...
    'BackgroundColor', [0.97 0.97 0.97], 'EdgeColor', [0.4 0.4 0.4], 'Margin', 4);

exportgraphics(fig, outPng, 'Resolution', 220);
close(fig);
fprintf('wrote %s\n', outPng);
end

function arrow(ax, u, z, c, w)
    plot(ax, u, z, '-', 'Color', c, 'LineWidth', w);
    d = [u(2)-u(1), z(2)-z(1)]; d = d / norm(d); n = [-d(2) d(1)]; L = 0.018; W = 0.009;
    tip = [u(2) z(2)]; b = tip - L*d;
    patch(ax, [tip(1) b(1)+W*n(1) b(1)-W*n(1)], [tip(2) b(2)+W*n(2) b(2)-W*n(2)], c, 'EdgeColor', c);
end

function tx(ax, u, z, s, c)
    text(ax, u, z, s, 'FontSize', 10, 'FontWeight', 'bold', 'Color', c);
end

function circ(ax, o, r, kind)
    t = linspace(0, 2*pi, 60);
    plot(ax, o(1)+r*cos(t), o(2)+r*sin(t), 'k-', 'LineWidth', 1.2);
    if kind == 'x'
        plot(ax, o(1)+r*[-1 1]*0.7, o(2)+r*[-1 1]*0.7, 'k-', 'LineWidth', 1.2);
        plot(ax, o(1)+r*[-1 1]*0.7, o(2)+r*[1 -1]*0.7, 'k-', 'LineWidth', 1.2);
    else
        plot(ax, o(1), o(2), 'k.', 'MarkerSize', 9);
    end
end

function dimv(ax, u, z1, z2, label)
    plot(ax, [u u], [z1 z2], 'k-', 'LineWidth', 0.7);
    plot(ax, u+[-0.012 0.012], [z1 z1], 'k-', 'LineWidth', 0.7);
    plot(ax, u+[-0.012 0.012], [z2 z2], 'k-', 'LineWidth', 0.7);
    plot(ax, [u 0], [z1 z1], 'k:', 'LineWidth', 0.5);
    plot(ax, [u 0], [z2 z2], 'k:', 'LineWidth', 0.5);
    text(ax, u-0.015, (z1+z2)/2, label, 'FontSize', 9, 'HorizontalAlignment', 'right');
end

function dimh(ax, z, u1, u2, label)
    plot(ax, [u1 u2], [z z], 'k-', 'LineWidth', 0.7);
    plot(ax, [u1 u1], z+[-0.012 0.012], 'k-', 'LineWidth', 0.7);
    plot(ax, [u2 u2], z+[-0.012 0.012], 'k-', 'LineWidth', 0.7);
    text(ax, (u1+u2)/2, z+0.022, label, 'FontSize', 9, 'HorizontalAlignment', 'center');
end
