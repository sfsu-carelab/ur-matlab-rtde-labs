# UR MATLAB RTDE Labs

A five-module, hands-on laboratory curriculum for teaching industrial robot operation,
safety, kinematics, and vision-guided automation to undergraduate engineering students,
using Universal Robots e-Series cobots controlled from MATLAB over RTDE.

Developed at San Francisco State University (School of Engineering). The materials work
with **any UR e-Series arm** (UR3e, UR5e, UR7e, UR10e, UR12e, UR16e, and the UR20/UR30
share the same kinematic structure); the worked examples show UR3e numbers.

## The labs

| Lab | Title | Students learn to |
|-----|-------|-------------------|
| 1 | Teach Pendant and Safety | Identify the hardware, power the arm on and off, configure payload/TCP, safety planes, limits, FreeDrive, e-stop and protective stop recovery |
| 2 | MATLAB + RTDE Setup | Network a PC to the robot, install the URCap and server script, connect from MATLAB with `urRTDEClient`, command a first motion |
| 3 | Forward Kinematics | Derive screw axes and the home pose from the robot's geometry (Product of Exponentials), verify against built-in self-tests and the physical robot |
| 4 | Pick-and-Place | Record waypoints, program the task on the Teach Pendant and again from MATLAB, compare the two workflows |
| 5 | Vision-Guided Pick-and-Place | Bring up an Intel RealSense camera in MATLAB, detect colored blocks by HSV, calibrate a pixel-to-robot mapping, and pick objects wherever they lie |

Each lab folder contains the student manual (.docx) and any accompanying MATLAB files.
The code is written so that an unfilled template fails safely: Lab 3's self-tests check
every joint of the student's derivation, and the motion scripts refuse to move the robot
until all waypoints are entered.

## Requirements

- Universal Robots e-Series arm running PolyScope X, with Teach Pendant
- Windows 10/11 PC with MATLAB (R2024b or newer recommended)
- [Robotics System Toolbox](https://www.mathworks.com/products/robotics.html) and the
  [Robotics System Toolbox Support Package for Universal Robots UR Series Manipulators](https://www.mathworks.com/hardware-support/universal-robots.html)
- Ethernet cable (direct connection, static IPs; Lab 2 walks through it)
- Robotiq 2F-85 gripper (Labs 1, 4, 5; other grippers work with minor changes, see the code comments)
- Lab 5 additionally: Intel RealSense D435if, Image Processing Toolbox, and a few colored blocks

## Getting started

1. Clone or download this repository.
2. Print or distribute the Lab 1 manual and start there; the labs build on each other in order.
3. Lab 2 connects the PC to the robot; every later lab assumes that setup.
4. For Lab 5, complete `resources/camera-setup/RealSense Set Up With MATLAB.docx` first.
   Run `test_vision_offline` in MATLAB (no robot or camera needed) to confirm the vision
   toolchain before class.

## Repository map

```
labs/                 one folder per lab: manual (.docx) + MATLAB files
assessment/
  paper-forms/        printable per-lab feedback questionnaires + end-of-series survey
  qualtrics/          the same instruments as Qualtrics import files (Advanced Format .txt);
                      the accessible/ variants use no matrix questions (WCAG friendly)
resources/
  camera-setup/       RealSense + MATLAB setup guide and printable camera mount CAD
                      (mount parts only; robot and gripper models come from UR and Robotiq)
```

## For instructors

- Solution files for Lab 3 and other instructor materials are deliberately not included
  in this public repository. Instructors can contact the author for the answer key.
- The assessment instruments were designed for course-improvement data collection. If you
  collect data for research, obtain your institution's IRB approval first.
- Lab 5's camera capture follows the Intel RealSense MATLAB wrapper; run it once on your
  lab PC with the camera attached before class.

## License

Code (MATLAB files) is released under the MIT License (see `LICENSE`). Lab manuals,
questionnaires, and other course materials are released under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): reuse and adapt freely with
attribution.

## Acknowledgments

Developed by Ryan Cullen (SFSU) as part of an M.S. thesis on robot hardware education.
Thanks to the MathWorks and Universal Robots communities for the toolboxes and
documentation this curriculum builds on.
