CoreVisualizer
==============

This tool is intended to proesent an active visual representation of the execution of a virtual CPU. It's something of a take on valgrind; it emulates a CPU core reading opcodes and does the syscalls and linking and all that itself instead of creating a full system environment like a true emulator would. The idea is that it's an abstration atop what a CPU is really doing, allowing you to see what a given flow of ASM code is doing in a visual representation of its effect, rather than worrying about nitty details of things like paging tables and stack frames and so forth that don't matter to 99% of coders.

Hopefully I'll eventually provide i386, x86_64, armv7, and arm64 "cores".

Obviously this is a work in progress; it doesn't do much yet.

This code is distributed under the terms of the MIT license:

```
The MIT License (MIT)

Copyright (c) 2013 Gwynne Raskind

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

