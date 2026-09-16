# Handover: hybrid 编译器增加 Linux x64 / ARM64 目标（进行中）

> 用途：在新会话/新机器上接着干。先通读"现状"与"当前阻塞点"，再按"下一步"执行。
> 仓库：`e:/temp3/red`（Windows 宿主，PowerShell Core）。所有行号锚点为撰写时的近似位置，以符号名搜索为准。

---

## 1. 任务与已确认范围

- 为**自举 hybrid（RSIR）编译链**增加 `Linux-X86-64` 与 `Linux-ARM64` 目标。
- Windows 上交叉编译 → 产物在 **WSL Ubuntu-24.04**（`wsl -d Ubuntu-24.04`）与 **armbian**（`ssh armbian`，aarch64 / Ubuntu 24.04 / glibc 2.39）上运行验证。
- 顺序：**先 Linux-x64，后 Linux-ARM64**。
- 测试深度：**全套**——Red/System 单测（40 个）+ Red 单测（57 个），对齐 Darwin-ARM64 的验证强度。
- 之后：编译器本体编为 Linux 版，在 WSL/armbian 上**自举**并做固定点验证。
- 硬约束：**不回归** Windows（Red 16,826 断言 / R-S 12,648 断言）与 Darwin-ARM64（Red 57/57、R-S 40/40）基线。

## 2. 自举纪律（AGENTS.md）

- 引导编译器：`build/self-hosting/merge-red64/hybrid-compilerNN.exe`（本分支已推进到 **80**，81 待重生成）。一律用
  `hybrid-compilerNN.exe -r -t Windows-X86-64 -o build/self-hosting/merge-red64/hybrid-compilerMM.exe red-bootstrap-windows-hybrid.red`
  （约 2 分钟）。**禁止 speed1**；每次构建检查 `$LASTEXITCODE`；新编译器必须先自编译验证；大里程碑单独 git commit。
- Windows 回归比对：`$env:SOURCE_DATE_EPOCH='1700000000'` 固定构建日期后逐字节比对新旧编译器对同一源的 PE 产物；允许差异仅限：PE 时间戳(0x88)、校验和(0xD8)、内嵌的编译器构建日期字符串/生成号。
- `red-console.exe` 可能挂死，必须带 timeout。

## 3. 已完成并已提交（commit `29a09a4ca`）

里程碑 1「ELF 接入与目标门禁」，全部验证通过：

- `system/compiler-hybrid-common.red`：include `formats/ELF.red`；`system-file-extension`/`emit-system-file`/`finish-system-file` 增 ELF 分支；`external-linker` 补 `cpp-entry/etls-off/etls-memsz/etls-filesz/etls-align/exidx-range` 字段与 `resolve-libname` ELF 分支；`make-system-file-executable` 扩展到 Linux 宿主（libc chmod）。
- `system/compiler-rsir-core.red`：`validate-job` 放行 Linux/ELF 的 x64(sysv) 与 ARM64(aapcs64)；链接模式校验要求 Linux 必须 PIC?+PIE?；dev-mode 运行时导入名/约定按 format 选择。
- `compiler/bootstrap-driver.red`：门禁放行；工具链 target 列表与 usage 更新；`libRedRT-target` 增补 Linux-ARM64-SO。
- `system/formats/ELF.red`：**双符号表兼容**（hybrid 是 map!，legacy 是 block!）；`collect-data-reloc` 的 map 分支把所有正 data-ref 视为需 R_X86_64_RELATIVE 回填的槽位；`build-dynamic`/`calc-dynamic-size` 的 symbols 参数去掉类型约束；导入段缺失时安全降级（无导入的 ARM64 程序可链接）。
- 已验证：`-n` noop 在 x64/arm64 均产出正确 ELF（WSL `file/readelf`：DYN+PIE、interpreter 正确、GNU_STACK RW、无 TEXTREL）；Windows 逐字节回归（仅 16 字节元数据差异）；Windows Red hello 正常运行。

## 4. 里程碑 2「Linux 启动装配」——设计与已完成（**未提交**）

### 4.1 最终设计（实施中收敛，与最初计划略有差异，以此为准）

Linux exe 不能让模块体直接当 ELF 入口：入口是裸栈（argc 在 [rsp]），且 libc 未初始化；而 hybrid codegen 的入口函数带完整 prologue，`pop`/`system/stack/top` 映射到真实 RSP 操作（codegen 中 stack natives = 真实 push/pop），因此 legacy `start.reds` 的 SVR4 裸栈代码无法在 prologued 函数内运行。**采用"启动寄存器契约"（Apple x19/x20 模式的推广）**：

1. **入口序言捕获**：Linux 入口函数在建立帧之前把裸栈指针存入启动寄存器——x64: `mov r12, rsp`；ARM64: `mov x19, sp`（在 emit-prologue 之前）。
2. **启动源**（新文件 `system/runtime/start-hybrid.reds`）：读 `system/cpu/r12` / `system/cpu/x19`，写 `***__argc`/`***__argv`（linux.reds 从这两个全局读参数），然后 `libc-start :***_start ***__argc ***__argv null null null hybrid-entry-stack`，末尾 `quit 1` 兜底。
3. **前端分流**：模块体编译为 `***_start`（普通函数，由 libc 以 main 身份回调），启动语句编译为入口函数 `***-start`（最后 add ⇒ entry=function-count ⇒ codegen 置于 code offset 0 ⇒ ELF e_entry）。
4. **Windows/Darwin 不变**：Win64 入口 OP_RETURN→合成 kernel32.dll/ExitProcess 导入的路径用 `target-abi = ABI_WIN64` 门控；ARM64 Apple 的 `mov x19,x0/mov x20,x1` 仅在 `ABI_APPLE_AARCH64` 时发射。
5. **仅 `job/runtime?` 时拼接启动源**（`-n` 的 Linux exe 入口直接返回，退出会崩——已知限制，后续可补合成 libc exit 导入）。

### 4.2 已改动的文件（全部未提交）

- `compiler/codegen-bridge.red` + `system/codegen/codegen-bridge.reds`：`codegen-module`/`run` 增加 `abi` 参数与常量（1=win64, 2=sysv, 3=apple-aarch64, 4=aapcs64）。
- `system/codegen/x64-codegen.reds`：`ABI_WIN64/ABI_SYSV` 常量与 `target-abi`；`generate` 增 abi 校验（错误码 1）；入口序言 sysv 时先发 `mov r12,rsp`；入口 wrapper 的 `allocate-frame` sysv=8（16 字节对齐）/win64=32（shadow space）；入口 OP_RETURN 的 ExitProcess 合成导入（plan 的 23 字节名区 + write 的导入记录 + call 回填）全部门控为 WIN64。
- `system/codegen/arm64-codegen.reds`：`ABI_APPLE_AARCH64/ABI_AAPCS64` 与 `target-abi`；`generate` 增 abi 校验（错误码 393）；aapcs64 启动捕获 = `mov x19, sp` 在 `emit-prologue` 之前（Apple 路径原样保留在序言之后）；注意 `written` 初始化为 0 后再拼接。
- `compiler/rsir-frontend.red`：新增 `startup-code/startup-locals/startup-line-table/startup-module?` 状态；`scan-block` 与 `stack-module` 各加 `#startup-code` 分支（下降分支保存/恢复 `active-module-code/locals` 与 `active-line-table`）；`compile-module` 在 `stack-module` 之前**提前注册 `***_start`**（否则启动代码里 `:***_start` 取不到址）；装配 case：有 startup 时只 `emit startup-code + add-module-function '***-start`（程序体已在 compile-module 注册）；reset 处清空新状态。
- `system/compiler-rsir-core.red`：`codegen-abi`（job/ABI → 判别值）并传入 `codegen-module`；Linux exe + runtime? 时经 `loader/process` 装载 `runtime-path/start-hybrid.reds`，用**显式重建块**拼到模块流头部（`merged-source`：`append/only source/1` + `append/only source/2` + `#startup-code` + `append/only skip startup-source 2` + `append skip source 2`）。
- `system/runtime/start-hybrid.reds`：新文件（内容见上）。
- ⚠️ **树里还有临时调试打印未删**：`compiler-rsir-core.red` 中 `...dbg startup-1/user-1/runtime-1`（3 处）与 `...rsir-source-1/2/len`（compile-rsir 内 3 处）。提交前必须删除。

### 4.3 踩过的坑（重要，勿重蹈）

- **`Red/System` 头字是 path!**：loader 返回的模块块首个元素是 path（Red/System），`append`/`insert` 会把它拆成 `Red` `System` 两个元素 → 必须用 `append/only` 保留单元素。
- **对 loader 产物做 `head insert skip source 2 ...` 会得到损坏的块**（source/1 变成 120 + 一堆 pair 行标记）——原因未深究，改用显式重建块后正常。
- **全局类型在下降期推断**：全局的"首次赋值"若在读取之后（下降顺序），读取处报 `local variable X used before being initialized!`（即便它是全局）→ 启动块必须**最先下降**（因此拼在流头部）。
- **`:***_start` 取址需要函数已注册**：模块体函数必须在下降前 `add-module-function`（汇编阶段不能重复注册）。
- loader 的 header 块内嵌 `(line x col)` pair 行标记——诊断打印里看到 `120 1x1 48x3...` 属正常（那是 header），不是源被换掉。

## 5. 当前阻塞点（接手后第一件事）

编译 `hello.reds -r -t Linux-X86-64` 报：

```
*** Script Error: emit does not allow none! for its <anon> argument
*** Near : compile-source source either runtime-library?
```

即前端 `compile-source` 执行期间某处 `emit <binary> ...` 的第一个参数为 none（很可能是 `active-module-code` 为 none，或装配处 `startup-code` 为 none）。排查建议：

1. 在前端 `emit` 定义处临时加断言/打印（binary? arg），定位调用点；
2. 重点检查 `compile-source` 装配 case（`emit module-code ...` / `emit startup-code ...`）与 `compile-module` 中提前注册的时序（`add-module-function` 记录引用的 `module-code` 二进制对象 vs `clear module-code` 时机）；
3. 检查 `lower-functions` 对"提前注册 + binary code"记录的处理（record/10 指令数、record/13 个槽位布局是否一致）；
4. 修好后依次验证：R/S hello（x64→WSL 运行出 `rs-linux-hybrid-ok`，exit 0）→ Red hello（x64）→ 两者 arm64（部署 armbian）→ 删调试打印 → Windows 逐字节回归 → commit 里程碑 2。

## 6. 关键事实速查（已核实）

- 门禁两处：`compiler/bootstrap-driver.red`（X86-64-Hybrid-only 分支）与 `system/compiler-rsir-core.red` `validate-job`。
- 目标元数据已在 `compiler/target-registry.red`：Linux-X86-64(sysv, PIC/PIE, /lib64/ld-linux-x86-64.so.2)、Linux-ARM64(aapcs64, /lib/ld-linux-aarch64.so.1)、两者 -SO 变体。
- `linker.red`：`load-codegen` 要求入口函数在 code offset 0；`resolve-symbol-refs` x64 用 RIP 相对位移（PIE 安全）；data-ref 正=写 dbuf / 负=写 robuf（绝对地址，PIC 下靠 R_RELATIVE 回填）；`***_start` 名字在调试栈回溯里有特殊 barrier（linker.red ~:903）。
- `ELF.red`：`build`(:445)；x64 PLT 回填 = `plt-offset + 16*index`；R_RELATIVE addend 取槽内 32 位；PIC 时 base-address=0。
- x64 codegen：`argument-register`=RCX/RDX/R8/R9（Win64）、shadow space、`win64-*` 辅助、入口 wrapper（root catch frame + call body + ud2，见 noop-win.exe 反汇编）；`plan-function-frame` 要求入口参数数=0；R12-R15 仅出现在 `cpu-register-id` 名字表（可安全用作启动寄存器）。
- arm64 codegen：`startup?` = kind 3 且读到 x19/x20（`startup-registers-used?`）；Apple 捕获在序言后；`move-register` 支持 SP 作源（add x19,sp,#0 编码）；支持 `#syscall`（x16+svc）。
- 前端：`system/cpu/<reg>` 读 = native 14（两 codegen 均实现）；`stack-module` 是模块体/启动语句的下降入口；`add-module-function` 追加 13 槽记录且注册 `function-ids`/`call-ids`。
- 运行时：`linux.reds` 读 `***__argc/***__argv`；`libc.reds` `quit: "exit"`；`common.reds` `LIBREDRT-file` 按 OS；`POSIX.reds` 非 macOS exe 走 `posix-startup-ctx/init`；`lib-names.reds` Linux=libc.so.6。
- 工具链资源：`tools/self_hosting/generate-toolchain-resources.red` 自动收集 `system/runtime/` 全部 .reds（start-hybrid.reds 会被收进内嵌档案，但需重生成工具链；当前磁盘读源编译器不受影响）。
- 测试模板：`build/darwin-hybrid/{build-rs-suite.sh,build-red-suite.sh,deploy-red-suite.sh}`；单测清单：`tools/self_hosting/run-red-unit-tests.red`（57）/`run-red-system-tests.red`（40）。

## 7. 常用命令

```powershell
# 构建新编译器（约2分钟，检查退出码）
cd e:\temp3\red
.\build\self-hosting\merge-red64\hybrid-compiler80.exe -r -t Windows-X86-64 -o build/self-hosting/merge-red64/hybrid-compiler81.exe red-bootstrap-windows-hybrid.red; "BUILD_EXIT=$LASTEXITCODE"

# 交叉编译 Linux-x64
.\build\self-hosting\merge-red64\hybrid-compiler81.exe -r -t Linux-X86-64 -o build/linux-hybrid/hello-rs-x64 build/linux-hybrid/hello.reds

# WSL 校验+运行
wsl -d Ubuntu-24.04 -- bash -lc "cp /mnt/e/temp3/red/build/linux-hybrid/hello-rs-x64 /tmp/h && chmod +x /tmp/h && readelf -h /tmp/h | head -8 && /tmp/h; echo EXIT=$?"

# Windows 逐字节回归（SOURCE_DATE_EPOCH 固定）
$env:SOURCE_DATE_EPOCH='1700000000'; <新旧编译器各编一次同一源>; # 比对字节差
```

armbian：`ssh armbian`（scp/tar 部署，`chmod +x` 后运行；readelf 校验 interpreter=/lib/ld-linux-aarch64.so.1）。

## 8. 剩余里程碑（对应 plan todo）

1. **linux-startup**（进行中）：修掉 §5 的 `emit none!` 错误 → x64/arm64 hello 上机 → 回归 → commit。
2. **x64-sysv-abi**：先用 code-explorer 子代理盘点 `x64-codegen.reds` 全部 Win64 依赖点（参数寄存器/shadow space/callee-saved/聚合与隐藏返回/变参 AL/对齐/入口退出），再参数化 SysV；Windows 逐字节回归为硬约束。
3. **linux-x64-e2e / linux-arm64-e2e**：hello + readelf 静态校验脚本化。
4. **rs-suite**：`build/linux-hybrid/`（或 linux-x64-hybrid/）三个脚本（build-rs-suite/build-red-suite/deploy-run），模板抄 darwin-hybrid；40/40。
5. **red-suite-regression**：57/57；Windows+Darwin 生成物回归比对。
6. **linux-selfhost**：编译器编为 Linux 版（x64 先、arm64 后），WSL/armbian 上自举 + 固定点验证（比生成物不比镜像）；重生成内嵌资源工具链；更新 AGENTS.md/handover；逐里程碑 commit。
