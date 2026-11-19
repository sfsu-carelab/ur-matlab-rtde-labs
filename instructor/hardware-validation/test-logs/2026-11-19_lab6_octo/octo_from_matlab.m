function octo_from_matlab(pyExe, vlapyDir, imgPath, task)
%OCTO_FROM_MATLAB  Call the Octo VLA from MATLAB R2024b with no Simulink.
%   Same calls as robotpolicy.m in mathworks/robot-vla-simulink (setupImpl / stepImpl),
%   but plain MATLAB: pyenv OutOfProcess, import octoModel, step(image, task).
    fprintf('MATLAB %s\n', version);
    terminate(pyenv);
    pe = pyenv(Version=pyExe, ExecutionMode="OutOfProcess");
    fprintf('pyenv: %s  (%s)\n', pe.Version, pe.Executable);
    if count(py.sys.path, vlapyDir) == 0
        insert(py.sys.path, int64(0), vlapyDir);
    end
    t = tic; py.importlib.import_module("octoModel"); fprintf('import octoModel: %.1f s\n', toc(t));
    t = tic; model = py.octoModel.OctoInference(); fprintf('OctoInference(): %.1f s\n', toc(t));
    img = imread(imgPath);
    fprintf('image %s\n', mat2str(size(img)));
    for k = 1:5
        t = tic;
        action = model.step(py.numpy.array(img), task);
        dt = toc(t);
        xyz     = double(action{2}{'world_vector'});
        rot     = double(action{2}{'rot_axangle'});
        gripper = double(action{2}{'gripper'});
        fprintf('step %d  %.2f s  dxyz = [%+.4f %+.4f %+.4f] m  drot = [%+.4f %+.4f %+.4f] rad  gripper = %+d\n', ...
            k, dt, xyz, rot, round(gripper));
    end
    terminate(pyenv);
end
