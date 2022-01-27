---
name: Bug report
about: Create a report to help us improve
title: "[BUG]"
labels: ''
assignees: OfficialLambdax

---

Template Note
**************************************************************************************************************
First of all make sure that you use the latest version of _netcode.
To see what version you use, check the variable $__net_sNetcodeVersion within the UDF header
and compare it with the top most version in the #changelog concept stage.txt, located in this repository. Im not supporting older versions of the UDF.

Second thing, enable the Tracer by toggling $__net_bTraceEnable = True right after you called _netcode_Startup(). When you run your Software with the tracer on, then it might logs errors to the console that already tell you whats wrong.

You can run your scripts (server / client) in SciTE at the same time. In the SciTE window, click Options and toggle "Open Files Here" off. The next script that you open will open in a new SciTE window. Press F5 in both windows to run both scripts at the same time.
**************************************************************************************************************

**Describe the bug you have**
here


**Tell me how i can reproduce the Bug**
Steps to reproduce the behavior:
1. 
2. 
3. 
4. 
n.


**Expected behavior**
A clear and concise description of what you expected to happen.


**If you can, then add Screenshots**
here


**On which Operating System apears the bug?**
 - OS? (Windows XP, Vista, 7, 8, 8.1, 10, 11 / Linux)
 - 32 or 64 Bit?
 - Autoit Stable or Beta?


**Additional context**
Add any other context about the problem here.


**If you can, then add a example script**
here
