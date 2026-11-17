# Emacs native compilation and Doom sync on macOS: conversation export

## 1. Native compiler errors at startup

**User:**

```text
"error invoking gcc driver" "/Applications/Emacs.app/Contents/Resources/lisp/emacs-lisp/gv.el.gz")
⛔ Warning (native-compiler): Internal native compiler error: "failed to compile", "/Users/alvaro/.config/emacs/eln-cache/31_1-032f33bc/gv-e0cf7478-7a3cbc20.eln", "error invoking gcc driver", "/Applications/Emacs.app/Contents/Resources/lisp/emacs-lisp/gv.el.gz"
⛔ Warning (native-compiler): libgccjit.so: error: error invoking gcc driver
⛔ Warning (native-compiler): Error: native-ice ("failed to compile" "/Users/alvaro/.config/emacs/eln-cache/31_1-032f33bc/cl-macs-7ae82f81-03fcdf23.eln" "error invoking gcc driver" "/Applications/Emacs.app/Contents/Resources/lisp/emacs-lisp/cl-macs.el.gz")
⛔ Warning (native-compiler): Internal native compiler error: "failed to compile", "/Users/alvaro/.config/emacs/eln-cache/31_1-032f33bc/cl-macs-7ae82f81-03fcdf23.eln", "error invoking gcc driver", "/Applications/Emacs.app/Contents/Resources/lisp/emacs-lisp/cl-macs.el.gz"
```

**Assistant:** This is a native-compilation failure. Emacs calls libgccjit, which tries to run a `gcc` driver and can't find one that works.

Quickest fix: silence the background compile warnings. Add to `~/.config/emacs/early-init.el`:

```elisp
(setq native-comp-async-report-warnings-errors 'silent)
```

Or disable compilation for now:

```elisp
(setq native-comp-jit-compilation nil)
```

Proper fix:

```sh
xcode-select --install
brew install gcc libgccjit
which gcc-14 gcc
rm -rf ~/.config/emacs/eln-cache
```

If the driver still doesn't resolve:

```elisp
(setq native-comp-driver-options '("-B/opt/homebrew/bin/"))
```

## 2. `gcc-14` not found

**User:**

```text
alvaros-MBP-M2 ➜  doom which gcc-14 gcc
gcc-14 not found
/usr/bin/gcc
```

**Assistant:** `/usr/bin/gcc` on macOS is Apple's clang wrapper, not GNU gcc, so libgccjit fails. Install GNU gcc through Homebrew:

```sh
brew install gcc libgccjit
ls $(brew --prefix)/bin | grep -E '^gcc-[0-9]+$'
```

Point Emacs at the Homebrew bin directory:

```elisp
(add-to-list 'exec-path "/opt/homebrew/bin")
(setenv "PATH" (concat "/opt/homebrew/bin:" (getenv "PATH")))
```

Clear the stale cache and restart:

```sh
rm -rf ~/.config/emacs/eln-cache
/opt/homebrew/bin/gcc-15 --version
```

## 3. `doom sync` fails on `let-completion`

**User:**

```text
alvaros-MBP-M2 ➜  doom doom sync
! (:ui doom-dashboard) module was moved to (:ui dashboard) in 2.1, remapping...
- Using Emacs 31.1 @ /Applications/Emacs.app/Contents/MacOS/Emacs-arm64-11
> Synchronizing 1 known profile...
  ✓ Regenerated profile loader: ~/.local/share/doom/profiles.el
> Synchronizing "_default" profile...
  ! Emacs version has changed since last sync (from 28.3 to 31.1)
  ! Your system has changed since last sync
    Installed packages must be rebuilt. Do so now? (y or n) y
  x There was an unexpected runtime error
    Message: Could not find package let-completion. Updating recipe repositories: (org-elpa melpa nongnu-elpa gnu-elpa-mirror el-get emacsmirror-mirror) with ‘straight-pull-recipe-repositories’ may fix this
    Backtrace:
      (error "Could not find package %S. Updating recipe repositories: %S wi...
      ...
    ! Wrote extended backtrace to ~/.config/emacs/.local/state/logs/cli.doom.261117133954.75096.error
✓ Finished in 4.13618s
```

**Assistant:** The failing package is `let-completion`. Straight.el can't find a recipe for it, so the recipe repos may be stale. Run:

```sh
doom sync -u
```

Or, inside Emacs: `M-x straight-pull-recipe-repositories`, then `doom sync`.

Check the recipe repos exist:

```sh
ls ~/.config/emacs/.local/straight/repos/
```

If the clones are missing, rebuild straight from scratch:

```sh
rm -rf ~/.config/emacs/.local/straight
doom sync
```

## 4. Analysing the error log

**User** attached `cli.doom.261117133954.75096.error` (434 KB). The assistant read the first 150 lines, then searched the file for `let-completion`, error headers and the failing `straight-use-package` calls. The key finding: the log's top-level error is `Could not find package let-completion`, and the backtrace shows Doom requesting the package from the `emacs-lisp` module. The rest of the 14,556-line backtrace is repeated frames and was not reproduced here.

## 5. Doom startup still fails on `let-completion`

**User:**

```text
  * 3:7.839740::context:module: =#s(doom-module-context 29 (:lang . org) /Users/alvaro/.config/emacs/sources/doom+/modules/lang/org nil nil)
  * 3:7.843896::context:module: =#s(doom-module-context 30 (:lang . sh) /Users/alvaro/.config/emacs/sources/doom+/modules/lang/sh nil nil)
  * 3:7.844735::context:module: =#s(doom-module-context 31 (:config . default) /Users/alvaro/.config/emacs/sources/doom+/modules/config/default (+bindings +smartparens) nil)
  * 3:7.845508::context:module: =#s(doom-module-context 1 (:user) /Users/alvaro/.config/doom/ nil nil)
  * 3:7.845818::context:module: =#s(doom-module-context 1 (:user) /Users/alvaro/.config/doom/ nil nil)
  x There was an unexpected runtime error
    Message: Could not find package let-completion. Updating recipe repositories: (org-elpa melpa nongnu-elpa gnu-elpa-mirror el-get emacsmirror-mirror) with ‘straight-pull-recipe-repositories’ may fix this
    Backtrace:
```

**Assistant:** Same failure. Find where `let-completion` is requested:

```sh
grep -rn "let-completion" ~/.config/emacs/sources/doom+ ~/.config/doom 2>/dev/null
ls ~/.config/emacs/.local/straight/repos/
```

## 6. Where `let-completion` comes from

**User:**

```text
alvaros-MBP-M2 ➜  ~ grep -rn "let-completion" ~/.config/emacs/sources/doom+ ~/.config/doom 2>/dev/null
ls ~/.config/emacs/.local/straight/repos/
/Users/alvaro/.config/emacs/sources/doom+/modules/lang/emacs-lisp/packages.el:16:(package! let-completion :pin "460cdd5a73d857d6d91469e28f84f02465db8dac")
/Users/alvaro/.config/emacs/sources/doom+/modules/lang/emacs-lisp/config.el:349:(use-package! let-completion
/Users/alvaro/.config/emacs/sources/doom+/modules/lang/emacs-lisp/config.el:350:  :hook (emacs-lisp-mode . let-completion-mode))
all-the-icons.el      dired-rsync           emacs-undo-fu  ...  straight.el
...
```

**Assistant:** The doom+ `emacs-lisp` module pins `let-completion` with no `:recipe`. Straight.el can't resolve it. The package exists upstream (MELPA readme, gggion repo). Add to `~/.config/doom/packages.el`:

```elisp
(package! let-completion
  :recipe (:host github :repo "gggion/let-completion.el"))
```

This overrides the module's pin. Add `:pin "460cdd5a..."` back only if the commit exists in that repo. To disable instead:

```elisp
(package! let-completion :disable t)
```

Note: doom+'s emacs-lisp config still calls `let-completion-mode`, so disabling may break on `.el` files.

Sources: gggion/let-completion.el, jcs-PR/let-completion.el, MELPA readme.

## 7. `package-lint` remote branch missing

**User:**

```text
$ cd /Users/alvaro/.config/emacs/.local/straight/repos/package-lint/
$ git fetch origin

fatal: couldn't find remote ref refs/heads/master

[Return code: 128]
```

**Assistant:** The upstream default branch is now `main`, but straight.el's clone expects `master`. Check branches:

```sh
git ls-remote --heads origin
```

Either fetch `main` and reset the clone, or delete the cache clone and re-sync (safe, straight.el re-clones it):

```sh
rm -rf ~/.config/emacs/.local/straight/repos/package-lint
doom sync
```

## 8. Boot error: native compile of `define-key` trampoline

**User:**

```text
⛔ Error (doom-after-modules-init-hook): Error running hook "general-auto-unbind-keys" because: (native-compiler-error Compiling /Users/alvaro/.config/emacs/.local/cache/eln/31_1-032f33bc/subr--trampoline-646566696e652d6b6579_define_key_0.eln...
ld: library 'emutls_w' not found
libgccjit.so: error: error invoking gcc driver
...
⛔ Warning (initialization): An error occurred while booting Doom Emacs:
...
```

(The full backtrace is omitted here; it runs through `general-advice-add`, `general-auto-unbind-keys` and `doom-run-hooks`.)

**Assistant:** `doom sync` now gets past `let-completion`. The remaining failure is in the linker: `emutls_w` is a GNU gcc library. Apple's `/usr/bin/gcc` is clang and doesn't ship it.

Fallback to unblock Doom, in `~/.config/emacs/early-init.el`:

```elisp
(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil)
```

Proper fix: find the gcc library and pass it to the driver:

```sh
brew install gcc libgccjit
find "$(brew --prefix gcc)/lib" -name 'libemutls_w.a'
```

## 9. Homebrew gcc is already installed

**User:**

```text
alvaros-MBP-M2 ➜  ~ brew install gcc libgccjit
find "$(brew --prefix gcc)/lib" -name 'libemutls_w.a'
Warning: gcc 16.2.0 is already installed and up-to-date.
Warning: libgccjit 16.2.0 is already installed and up-to-date.
/opt/homebrew/opt/gcc/lib/gcc/current/gcc/aarch64-apple-darwin24/16/libemutls_w.a
```

**Assistant:** Add the library directory and Homebrew `bin` to `early-init.el`:

```elisp
(setenv "PATH" (concat "/opt/homebrew/bin:" (getenv "PATH")))
(setq exec-path (cons "/opt/homebrew/bin" exec-path))
(setq native-comp-driver-options
      '("-L/opt/homebrew/opt/gcc/lib/gcc/current/gcc/aarch64-apple-darwin24/16"))
```

Clear the cache and restart:

```sh
rm -rf ~/.config/emacs/.local/cache/eln
```

## 10. Pinned `dirvish` commit missing

**User:**

```text
alvaros-MBP-M2 ➜  ~ doom sync
...
  > Updating pinned packages...
    > (61/125) Re-cloning dirvish...
    ✓ (61/125) dirvish: 9b9ed2d -> 300b6b2 [1 commit(s)]
        ERROR: Couldn't collect commit list because: fatal: bad object 300b6b2536006aaf5f803775ca93ca5f6ec35de1
```

**Assistant:** The pinned commit is not in the upstream dirvish repo. Check:

```sh
cd ~/.config/emacs/.local/straight/repos/dirvish
git fetch --all --tags
git cat-file -t 300b6b2536006aaf5f803775ca93ca5f6ec35de1
```

Find the pin:

```sh
grep -rn "dirvish" ~/.config/emacs/sources/doom+/modules ~/.config/doom/packages.el
```

Unpin in `~/.config/doom/packages.el`:

```elisp
(package! dirvish :pin nil)
```

**User:**

```text
alvaros-MBP-M2 ➜  ~ cd ~/.config/emacs/.local/straight/repos/dirvish
git fetch --all --tags
git cat-file -t 300b6b2536006aaf5f803775ca93ca5f6ec35de1
fatal: git cat-file: could not get object info
```

**Assistant:** The commit isn't in upstream. Unpin dirvish as above, then run `doom sync`.

## 11. `libSystem` not found

**User:**

```text
Debugger entered--Lisp error: (native-compiler-error "Compiling /Users/alvaro/.config/emacs/.local/cache/eln/31_1-032f33bc/subr--trampoline-646566696e652d6b6579_define_key_0.eln...\nld: library 'System' not found\nlibgccjit.so: error: error invoking gcc driver\n...
```

(The full backtrace is omitted here; it is the same native-compiler trampoline path as section 8.)

**Assistant:** The linker can't find `libSystem`, the macOS system library, so the gcc driver needs the SDK location. Get it with:

```sh
xcrun --show-sdk-path
```

Add the SDK's `usr/lib` to the driver options. Then clear the cache and sync:

```elisp
(setq native-comp-driver-options
      '("-L/opt/homebrew/opt/gcc/lib/gcc/current/gcc/aarch64-apple-darwin24/16"
        "-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"))
```

```sh
rm -rf ~/.config/emacs/.local/cache/eln
doom sync
```

**User:**

```text
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

**Assistant:** Use the Xcode SDK path:

```elisp
(setq native-comp-driver-options
      '("-L/opt/homebrew/opt/gcc/lib/gcc/current/gcc/aarch64-apple-darwin24/16"
        "-L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib"))
```

**User:**

```text
⛔ Error (doom-after-modules-init-hook): Error running hook "general-auto-unbind-keys" because: (native-compiler-error Compiling ...subr--trampoline-646566696e652d6b6579_define_key_0.eln...
ld: library 'System' not found
libgccjit.so: error: error invoking gcc driver
...
```

**Assistant:** The SDK path didn't fix it. Stop fighting the toolchain and turn native compilation off. In `~/.config/emacs/early-init.el`, replace the driver options with:

```elisp
(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil
      native-comp-async-report-warnings-errors 'silent)
```

Then:

```sh
rm -rf ~/.config/emacs/.local/cache/eln ~/.config/emacs/.local/cache/eln-cache
doom sync
```

Doom and Emacs run without native compilation, just more slowly. Native compilation can be revisited later with a matching libgccjit and gcc setup.

## 12. Export request

**User:** export this conversation as .md (with codefences) and give me the file
