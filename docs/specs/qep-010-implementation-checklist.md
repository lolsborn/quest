# QEP-010 I/O Redirection - Implementation Checklist

**Status:** In Progress
**Phase:** Phase 1 (Manual Guards)
**Updated:** 2025-10-05

## Current Status

### ✅ Completed (Foundation)
- [x] Create `src/types/system_stream.rs` - QSystemStream type
- [x] Create `src/types/redirect_guard.rs` - QRedirectGuard type
- [x] Add SystemStream and RedirectGuard to QValue enum
- [x] Add to all QValue match statements (as_obj, as_str, as_bool, as_num, q_type)
- [x] Add to method dispatch in main.rs
- [x] Add to JSON conversion (error case)
- [x] Add sys.stdout, sys.stderr, sys.stdin singletons to sys module
- [x] Implement QSystemStream.write() method
- [x] Implement QSystemStream.flush() method
- [x] Test sys.stdout.write() - Working ✅

### 🚧 In Progress (Core Redirection)

#### Step 1: Add OutputTarget Enum
- [ ] Define OutputTarget enum in main.rs or separate file
  ```rust
  pub enum OutputTarget {
      Default,           // OS stdout/stderr
      File(String),      // File path (opens/appends on each write)
      StringIO(Rc<RefCell<QStringIO>>),  // In-memory buffer
  }
  ```
- [ ] Implement OutputTarget::write(&mut self, data: &str) method
- [ ] Handle Default case (print!/eprint!)
- [ ] Handle File case (append to file)
- [ ] Handle StringIO case (buffer.borrow_mut().write())
- [ ] Make OutputTarget Clone

#### Step 2: Modify Scope Structure
- [ ] Find Scope struct definition in main.rs
- [ ] Add field: `pub stdout_target: OutputTarget`
- [ ] Add field: `pub stderr_target: OutputTarget`
- [ ] Initialize both to OutputTarget::Default in Scope::new()
- [ ] Update all Scope::new() call sites if needed

#### Step 3: Implement RedirectGuard.restore()
- [ ] Add method to QRedirectGuard that takes &mut Scope
  ```rust
  pub fn restore(&self, scope: &mut Scope) -> Result<(), String>
  ```
- [ ] Check if guard is_active() (idempotent check)
- [ ] Take previous_target from RefCell (makes it None)
- [ ] Match on stream_type (Stdout or Stderr)
- [ ] Restore scope.stdout_target or scope.stderr_target
- [ ] Return Ok(())

#### Step 4: Wire Up RedirectGuard Method Calls
- [ ] Find where method calls happen with scope access
- [ ] Add special case for RedirectGuard.restore()
  ```rust
  QValue::RedirectGuard(rg) if method_name == "restore" => {
      rg.restore(scope)?;
      Ok(QValue::Nil(QNil))
  }
  ```
- [ ] Add RedirectGuard.is_active()
  ```rust
  QValue::RedirectGuard(rg) if method_name == "is_active" => {
      Ok(QValue::Bool(QBool::new(rg.is_active())))
  }
  ```
- [ ] Add RedirectGuard._enter() and _exit() for context manager support

#### Step 5: Implement sys.redirect_stdout()
- [ ] Add to call_sys_function() in modules/sys.rs
- [ ] Parse target argument (Str for file path, StringIO object)
- [ ] Create OutputTarget from argument
- [ ] Save current scope.stdout_target (clone it)
- [ ] Replace scope.stdout_target with new target
- [ ] Create QRedirectGuard with saved previous target
- [ ] Return guard wrapped in QValue::RedirectGuard(Box::new(guard))

Example code:
```rust
"sys.redirect_stdout" => {
    if args.len() != 1 {
        return Err(format!("redirect_stdout expects 1 argument, got {}", args.len()));
    }

    // Parse target
    let new_target = match &args[0] {
        QValue::Str(s) => OutputTarget::File(s.value.to_string()),
        QValue::StringIO(sio) => OutputTarget::StringIO(Rc::clone(sio)),
        QValue::SystemStream(ss) if ss.stream_id == 0 => OutputTarget::Default,
        _ => return Err("redirect_stdout: target must be String (path), StringIO, or sys.stdout".to_string()),
    };

    // Save previous and set new
    let previous = scope.stdout_target.clone();
    scope.stdout_target = new_target;

    // Return guard
    let previous_path = match previous {
        OutputTarget::File(path) => Some(path),
        _ => None,
    };
    let guard = QRedirectGuard::new(StreamType::Stdout, previous_path);
    Ok(QValue::RedirectGuard(Box::new(guard)))
}
```

#### Step 6: Implement sys.redirect_stderr()
- [ ] Same as redirect_stdout but for stderr
- [ ] Uses scope.stderr_target instead
- [ ] Creates guard with StreamType::Stderr

#### Step 7: Modify puts() to Use Redirection
- [ ] Find puts() implementation in main.rs
- [ ] Instead of `println!()`, use scope.stdout_target.write()
- [ ] Handle errors from write()
- [ ] Add newline to output string

Example code:
```rust
"puts" => {
    let mut output = String::new();
    for arg in &args {
        output.push_str(&arg.as_str());
    }
    output.push('\n');

    scope.stdout_target.write(&output)?;
    Ok(QValue::Nil(QNil))
}
```

#### Step 8: Modify print() to Use Redirection
- [ ] Find print() implementation in main.rs
- [ ] Use scope.stdout_target.write() instead of print!()
- [ ] No newline (unlike puts)

### 🧪 Testing

#### Step 9: Write Test Suite
- [ ] Create `test/sys/redirect_test.q`
- [ ] Test redirect to StringIO:
  ```quest
  let buf = io.StringIO.new()
  let guard = sys.redirect_stdout(buf)
  puts("Captured")
  guard.restore()
  test.assert_eq(buf.get_value(), "Captured\n", nil)
  ```
- [ ] Test redirect to file path:
  ```quest
  let guard = sys.redirect_stdout("/tmp/test.txt")
  puts("To file")
  guard.restore()
  let content = io.read("/tmp/test.txt")
  test.assert(content.contains("To file"), nil)
  ```
- [ ] Test redirect to /dev/null:
  ```quest
  let guard = sys.redirect_stdout("/dev/null")
  puts("Suppressed")
  guard.restore()
  ```
- [ ] Test guard.is_active()
- [ ] Test idempotent restore() (call multiple times)
- [ ] Test nested redirections
- [ ] Test exception safety (restore in ensure block)
- [ ] Test redirect_stderr separately
- [ ] Test sys.stderr.write() still works when redirected

#### Step 10: Test Context Manager Support
- [ ] Test with statement:
  ```quest
  with sys.redirect_stdout(buffer) as guard
      puts("Captured")
  end
  ```
- [ ] Test automatic restoration on exception
- [ ] Test nested with blocks

### 📝 Documentation

#### Step 11: Create Documentation
- [ ] Create `lib/std/sys.q` or update existing
- [ ] Document sys.stdout, sys.stderr, sys.stdin
- [ ] Document sys.redirect_stdout(target)
- [ ] Document sys.redirect_stderr(target)
- [ ] Document RedirectGuard.restore()
- [ ] Document RedirectGuard.is_active()
- [ ] Add usage examples
- [ ] Add security notes (file paths, permissions)

#### Step 12: Update CLAUDE.md
- [ ] Add to std/sys section:
  - sys.stdout, sys.stderr, sys.stdin singletons
  - sys.redirect_stdout() and sys.redirect_stderr()
  - RedirectGuard type
  - Usage examples

#### Step 13: Update README.md
- [ ] Mention I/O redirection in features (if user-facing)
- [ ] Add to stdlib section if appropriate

### 🐛 Edge Cases and Error Handling

#### Step 14: Handle Edge Cases
- [ ] What if file can't be opened? (permissions, invalid path)
- [ ] What if writing to file fails mid-operation?
- [ ] What if StringIO is used after redirection ends?
- [ ] What if guard.restore() called after scope is gone?
- [ ] What if user redirects to same target twice?
- [ ] What if restore() called without guard?
- [ ] Handle binary data in redirected output

#### Step 15: Error Messages
- [ ] Clear error for invalid redirect target type
- [ ] Clear error for file permission issues
- [ ] Clear error for calling guard.restore() when not active (should be no-op)
- [ ] Clear error for /dev/null on Windows (need alternative?)

### 🔧 Refactoring and Optimization

#### Step 16: Performance Optimization
- [ ] Consider buffering for file writes (currently opens/writes/closes each time)
- [ ] Maybe keep file handle open instead of path?
- [ ] Profile redirection overhead

#### Step 17: Code Cleanup
- [ ] Remove temporary comments
- [ ] Ensure consistent error messages
- [ ] Add doc comments to Rust code
- [ ] Follow Quest coding conventions

### ✅ Final Verification

#### Step 18: Integration Testing
- [ ] Run full test suite (all 791+ tests)
- [ ] Ensure no regressions
- [ ] Test with gzip compression tests (should still pass)
- [ ] Test with StringIO tests (should still pass)

#### Step 19: Build Verification
- [ ] Cargo build --release (0 warnings)
- [ ] Cargo clippy (0 warnings)
- [ ] No unused imports
- [ ] No dead code warnings

#### Step 20: Documentation Verification
- [ ] All examples in docs actually work
- [ ] lib/std/sys.q examples can be copy-pasted
- [ ] QEP-010 spec matches implementation
- [ ] CLAUDE.md is accurate

### 📦 Completion Criteria

**Ready to merge when:**
- [ ] All checklist items complete
- [ ] All new tests passing (estimated 15-20 tests)
- [ ] No regressions in existing tests
- [ ] Documentation complete and accurate
- [ ] Build clean (0 warnings, 0 errors)
- [ ] QEP-010 Phase 1 checklist in spec is complete

## Estimated Effort

**Completed so far:** ~1 hour (foundation types)

**Remaining work:**
- Steps 1-8 (Core implementation): **2-3 hours**
- Steps 9-10 (Testing): **1-2 hours**
- Steps 11-13 (Documentation): **1 hour**
- Steps 14-20 (Polish and verification): **1 hour**

**Total remaining: 5-7 hours**

## Notes

- RedirectGuard currently stores only file paths (String) in previous_target
- Will need to store full OutputTarget for complete StringIO support
- guard.restore() needs scope access - requires careful method dispatch
- Context manager (_enter/_exit) already scaffolded in QRedirectGuard

## Blockers

None currently - foundation is solid, just needs the implementation work.

## Questions to Resolve

1. Should OutputTarget be in main.rs or separate file in types/?
2. Keep file handle open or open/close each write?
3. How to handle /dev/null on Windows? (NUL device?)
4. Should we support File objects as targets (QEP-011 dependency)?

## Success Metrics

- [ ] Can redirect puts() to StringIO
- [ ] Can redirect to file path
- [ ] Can suppress with /dev/null
- [ ] Guards are idempotent
- [ ] Nested redirections work
- [ ] Exception safety works (restore in ensure)
- [ ] Context manager integration works
- [ ] All tests passing
