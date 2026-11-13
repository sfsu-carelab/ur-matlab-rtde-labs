"""Lab 2 manual Rev9 from Rev8: the Ready Position smart skill sentence in Part 6 is replaced
by a jogged ready position of the students' choosing (Ryan, 2026-11-13). Nothing else changes.
usage: build_lab2_rev9.py <Rev8 docx> <out docx>"""
import sys, zipfile
from lxml import etree
from dx import *
zin = zipfile.ZipFile(sys.argv[1]); doc = etree.fromstring(zin.read('word/document.xml'))
hits = [p for p in doc.iter(w('p')) if text_of(p).startswith('Always move the arm back to the Ready Position')]
assert len(hits) == 1
setpar(hits[0], 'Before sending commands, jog the arm to a ready position of your choosing: shoulder and elbow bent, tool flange facing down, and the gripper well above the table.')
zout = zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED)
for info in zin.infolist():
    data = zin.read(info.filename)
    if info.filename == 'word/document.xml': data = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' + etree.tostring(doc, encoding='UTF-8')
    zout.writestr(info, data)
zout.close(); print('wrote', sys.argv[2])
