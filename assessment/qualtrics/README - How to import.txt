HOW TO IMPORT THESE SURVEYS INTO QUALTRICS
------------------------------------------
Each .txt file in this folder is one complete survey in Qualtrics
"Advanced Format". For each file:

1. In Qualtrics: Create a new project > Survey > "Import a QSF or TXT file"
   (wording varies slightly: look for import from file when creating a survey).
2. Choose the .txt file and import. Every question, choice, scale, and page
   break comes in automatically.
3. Name the project to match the file (for example "Lab 3 Feedback").
4. In Survey Options, set: anonymize responses ON (do not record IP or
   location), and turn OFF "prevent multiple submissions" only if students
   share lab computers.
5. Preview once, then publish and distribute via the anonymous link.

Question IDs are set for clean data columns (MODEL, PRIOR, LO, DIFF, TIME,
MINUTES, FINISHED, CLARITY, STUCK, IMPROVE; the Experience survey adds
STANDING, LABSDONE, RETRO_BEFORE, RETRO_NOW, EXP, TOOLPREF, MOSTVAL,
LEASTVAL, ORDER, PACE, FUTURE, and the open-feedback fields).

The per-lab surveys are taken right after each lab session. The
"UR MATLAB Experience" survey is taken ONCE, after the final lab; it now
owns the whole-series questions that used to be Section E of the Lab 4 form.

If your study feeds the ASEE paper or thesis, confirm the IRB protocol is in
place before distributing.


ACCESSIBILITY (WCAG) WARNING AFTER IMPORT
-----------------------------------------
ExpertReview flags Likert MATRIX questions as not WCAG 2.0 AA compliant in
Qualtrics' LEGACY survey-taking experience. Two ways to resolve it:

1. PREFERRED: switch the survey to the NEW survey taking experience
   (Look and feel; if the survey is on legacy there is an upgrade control).
   Matrix questions ARE compliant there (checked to WCAG 2.2 AA). Also set
   each matrix question to Mobile friendly. Then re-run the checker.

2. OR import the versions in "accessible - no matrix questions/" instead:
   identical content, but every scale statement is its own horizontal
   radio-button question (an accessible type in every experience), with the
   scale legend shown once above each group. Data columns become LO_1, LO_2,
   ... instead of one matrix. No warnings in either experience.

Do not mix the two versions of the same survey; pick one per survey before
distributing.
