# Foundations: Memory, C, and Assembly

Lab notes for `01-foundations`. The goal of this stage is to understand what a
program looks like while it runs: how a stack frame is laid out, where a local
buffer sits relative to the saved return address, and why writing past the end
of a buffer is dangerous.

## Build

All binaries are compiled with debug symbols, no PIE, no optimization, and no
stack protector, so that addresses are stable and the disassembly maps cleanly
onto the C source:

```bash
gcc -g -O0 -no-pie -fno-stack-protector -o mem mem.c
```

---

## Stack frame map of `greet()`

Target program:

```c
void greet(void) {
    char name[32];
    printf("Name: ");
    fgets(name, sizeof(name), stdin);
    printf("Hello, %s", name);
}

int main(void) {
    greet();
    return 0;
}
```

From this:

- `name` lives at `0x7fffffffdc80`, which is `$rbp - 0x20`.
- The saved RBP is at `0x7fffffffdca0` (`$rbp`) and holds `0x7fffffffdcb0`
  (the caller's base pointer).
- The saved return address is at `0x7fffffffdca8` (`$rbp + 0x08`) and holds
  `0x401191`, which is `main+9` — the instruction the CPU returns to after `ret`.

### Frame layout

Each label below names is the **start (lowest) address** of the box it points to.

```
+------------------------------+
| return address   0x401191    |   @ 0x7fffffffdca8  ($rbp + 0x08)   -> main+9
+------------------------------+
| saved RBP        0x...dcb0   |   @ 0x7fffffffdca0  ($rbp)
+------------------------------+
| char name[32]                |   @ 0x7fffffffdc80  ($rbp - 0x20) = $rsp
+------------------------------+
```

#### gdb log:

```
pwndbg> p &name
$1 = (char (*)[32]) 0x7fffffffdc80

pwndbg> x/6gx $rbp
0x7fffffffdca0: 0x00007fffffffdcb0      0x0000000000401191
0x7fffffffdcb0: 0x00007fffffffddd8      0x00007ffff7dd3fba
0x7fffffffdcc0: 0x00007fffffffdd90      0x0000000000401188
```

#### Distance from buffer to return address:

```
buffer start   = $rbp - 0x20
return address = $rbp + 0x08

distance = 0x20 + 0x08 = 0x28 = 40 bytes
```

---

## Resizing the buffer to 100

After changing `char name[32]` to `char name[100]` and recompiling, three
instructions in the disassembly change.

| Instruction          | buffer = 32      | buffer = 100     |
|----------------------|------------------|------------------|
| frame allocation     | `sub rsp, 0x20`  | `sub rsp, 0x70`  |
| address of buffer    | `lea rax,[rbp-0x20]` | `lea rax,[rbp-0x70]` |
| size passed to fgets | `mov esi, 0x20` (32) | `mov esi, 0x64` (100) |

The new distance from the buffer to the return address:

```
0x70 + 0x08 = 0x78 = 120 bytes
```

#### But Why the frame is 0x70 (112) and not 0x64 (100) ?

The buffer is 100 bytes (`0x64`), but the frame is 112 bytes (`0x70`). The extra
**12 bytes (`0x0C`)** are stack-alignment padding.

The System V ABI(standard interface calling conventions) requires `rsp` to be 16-byte aligned at the point of a `call`.
On entry to `greet`, `call` has already pushed the 8-byte return address, so
`rsp ≡ 8 (mod 16)`. The `push rbp` in the prologue pushes another 8 bytes,
bringing `rsp` back to a 16 byte boundary. For the stack to stay aligned through
the next `call`, the frame reserved by `sub rsp, N` must itself be a multiple of
16. 100 is not a multiple of 16, so the compiler rounds up with padding to the next one:

```
100 (0x64) + 12 (0x0C) = 112 (0x70)
```

Those 12 padding bytes sit **between the end of the buffer and the saved RBP**:
the buffer occupies `rbp-0x70` up to `rbp-0x0C`, and `rbp-0x0C` .. `rbp` is padding.

---

## Two buffers and variables order

Small program with two local arrays to observe how they are placed in the frame:

```c
void two_buffers(void) {
    char buffer_one[40];
    char buffer_two[60];
    fgets(buffer_one, sizeof(buffer_one), stdin);
    fgets(buffer_two, sizeof(buffer_two), stdin);
    printf("buffer_one: %s\nbuffer_two: %s", buffer_one, buffer_two);
}

int main(void) {
    two_buffers();
    return 0;
}
```

#### gdb log

```
pwndbg> p &buffer_one
$2 = (char (*)[40]) 0x7fffffffdc50      # rbp - 0x30  (higher address)
pwndbg> p &buffer_two
$3 = (char (*)[60]) 0x7fffffffdc10      # rbp - 0x70  (lower address)
```

So `buffer_one` (declared first) ends up at the **higher** address, closer to
`rbp`, and `buffer_two` sits below it.

The allocation is `0x70` = 112 bytes for 40 + 60 = 100 bytes of arrays:

- `buffer_one` gets the 48 bytes (`0x30`) from `rbp-0x30` to `rbp`.
- `buffer_two` gets the 64 bytes (`0x40`) from `rbp-0x70` to `rbp-0x30`.

Each buffer is rounded up to a 16-byte boundary .

#### Why buffer_two is in lower address ?

The buffers/local variables is reserved in one shot by `sub rsp, 0x70`, then the compiler 
assigns each local a fixed offset *inside* that already allocated region. Stack
growth direction **doesn't** determine the order of variables in a single
frame ,this decosion is purely the comp decision.

In this build, it happen to place the first-declared variable closest to `rbp`.
A different compiler (clang), a different optimization level,
or `-fstack-protector` (which deliberately change arrays order to sit next to the
stack canary) can all produce a different layout.

#### Conclusion:
local variable order is build specific, never assumed order from the source.

---

## Long input: `fgets` vs `gets`

#### Observed behavior with `fgets`

Running `mem` and typing more than 32 characters doesn't crash or give segfault.
The program prints the first 31 characters and exits cleanly.

#### Why we dont get overflow ?

`fgets(name, sizeof(name), stdin)` is bounded. By definition it reads at most
`N-1` characters (31 here), reserves the final byte for the null terminator
`'\0'`, and leaves the remaining input in the stdin buffer and not copied
to the stack. The frame stays intact without corruption.

#### What `gets` would do

`gets()` is older way to get user input that was removed from C11 version due to severe security issues.
`gets(name)` takes only a pointer, with no size limit, so it keeps writing until
it hits a newline. Walking up from the buffer:

| Input bytes | Destination                         |
|-------------|-------------------------------------|
| 1 – 32      | fill `name` (`rbp-0x20` .. `rbp`)   |
| 33 – 40     | overwrite the saved RBP             |
| 41 – 48     | overwrite the saved return address  |

So from **offset 40** onward the return address is being overwritten. Note that
`gets` also appends its own `'\0'`, so even exactly 40 input characters corrupts
the lowest byte of the return address.

#### Where the crash actually happens

If the overwrite is garbage with invaild address. The fault occurs on the `ret`
instruction itself when the CPU try to load that invalid address to `rip`, the running
will stop *at* `ret`, not at the invaild address.

#### Why this matters

Because the attacker controls the bytes that land on the return address, they
control where execution goes after `ret`. If a program hides functionality
behind a check (for example, a "secret" function reachable only with the right
password), an overflow lets you write the return address and jump to that 
function's address and bypassing the check.

One practical note that ties back to the Resizing the buffer section:
after such a jump the stack is often misaligned by 8 bytes, and some libc
routines can crash for exactly that reason.
The common attacker "fix" is to prepend an extra `ret` that add 8 bytes to $rsp
and aligned with the 16-byte alignment rule seen earlier.


